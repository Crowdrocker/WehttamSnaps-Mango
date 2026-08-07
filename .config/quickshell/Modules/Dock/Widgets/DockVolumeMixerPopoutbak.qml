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
    property real   popupDistance: Theme.popupDistance ?? 8
    property bool   showPopup:     false
    property bool   shouldBeVisible: showPopup

    property real   storedTriggerX:       0
    property real   storedTriggerY:       0
    property real   storedTriggerWidth:   70
    property string storedTriggerSection: "right"
    property var    storedTriggerScreen:  null

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
            const sx  = screen.x || 0
            const sy  = screen.y || 0
            const tbT = root.barThickness
            const gap = root.popupDistance + 15
            const gp  = root.anchorItem.mapToGlobal(0, 0)
            let tx, ty

            if      (root.barPosition === "top")    { tx = gp.x - sx + root.anchorItem.width / 2;  ty = sy + tbT + gap }
            else if (root.barPosition === "bottom")  { tx = gp.x - sx + root.anchorItem.width / 2;  ty = sy + screen.height - tbT - gap }
            else if (root.barPosition === "left")    { tx = sx + tbT + gap;                          ty = gp.y - sy + root.anchorItem.height / 2 }
            else if (root.barPosition === "right")   { tx = sx + screen.width - tbT - gap;           ty = gp.y - sy + root.anchorItem.height / 2 }
            else                                     { tx = sx + screen.width / 2;                   ty = sy + screen.height / 2 }

            anchorPos = Qt.point(tx, ty)
        }

        // ── Popup card ────────────────────────────────────────────────────────

        Rectangle {
            id: card

            width: Math.min(400, popupWindow.screen.width - 24)
            height: Math.min(
                        innerColumn.implicitHeight + Theme.spacingL * 2,
                        popupWindow.screen.height - 80)

            onWidthChanged:  popupWindow.updatePosition()
            onHeightChanged: popupWindow.updatePosition()

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

            radius:       Theme.widgetRadius + 2
            color:        Theme.popupBackground()
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
            border.width: 1
            opacity: root.showPopup ? 1 : 0
            scale:   root.showPopup ? 1 : 0.92
            clip:    true

            Behavior on opacity { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }
            Behavior on scale   { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

            Rectangle {
                anchors { fill: parent; topMargin: 4; leftMargin: 2; rightMargin: -2; bottomMargin: -4 }
                radius: parent.radius
                color:  Theme.shadowMedium
                z:      -1
            }

            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
            }

            // ── Header bar ────────────────────────────────────────────────────

            Rectangle {
                id: headerBar
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: Theme.spacingL * 2 + Theme.fontSizeSmall + 4
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                radius: card.radius

                // Bottom corners square so it blends into card
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: parent.radius
                    color: parent.color
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: Theme.spacingM; rightMargin: Theme.spacingM }
                    spacing: Theme.spacingS

                    EHIcon {
                        name: AudioService.getOutputIcon()
                        size: Theme.fontSizeMedium
                        color: AudioService.muted ? Theme.error : Theme.primary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: AudioService.sink ? AudioService.displayName(AudioService.sink) : "No Output"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: "·"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        Layout.alignment: Qt.AlignVCenter
                        visible: AudioService.hasInput
                    }

                    EHIcon {
                        name: AudioService.getInputIcon()
                        size: Theme.fontSizeMedium
                        color: AudioService.inputMuted ? Theme.error : Theme.surfaceTextMedium
                        Layout.alignment: Qt.AlignVCenter
                        visible: AudioService.hasInput
                    }

                    StyledText {
                        text: AudioService.source ? AudioService.displayName(AudioService.source) : ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        elide: Text.ElideRight
                        Layout.preferredWidth: implicitWidth
                        Layout.alignment: Qt.AlignVCenter
                        visible: AudioService.hasInput
                    }
                }
            }

            // ── Scrollable content ────────────────────────────────────────────

            Flickable {
                id: flickable
                anchors {
                    top: headerBar.bottom
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: Theme.spacingL
                }
                contentHeight: innerColumn.implicitHeight
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: innerColumn
                    width: flickable.width
                    spacing: Theme.spacingM

                    // ── OUTPUT DEVICES ────────────────────────────────────────

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        // Section header
                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingS

                            EHIcon {
                                name: "speaker"
                                size: Theme.fontSizeMedium
                                color: Theme.primary
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledText {
                                text: "Output"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.SemiBold
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        // Device list
                        Repeater {
                            model: AudioService.sinks

                            delegate: Rectangle {
                                required property PwNode modelData
                                required property int    index

                                property PwNodeAudio nodeAudio: modelData?.audio ?? null
                                property bool isDefault: AudioService.sink === modelData
                                property real devVolume: nodeAudio?.volume ?? 0
                                property bool devMuted:  nodeAudio?.muted  ?? false

                                PwObjectTracker { objects: modelData ? [modelData] : [] }

                                width:  flickable.width
                                height: devContent.implicitHeight + Theme.spacingM * 2
                                radius: Theme.widgetRadius
                                color: isDefault
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.09)
                                    : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.14)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, isDefault ? 0.22 : 0.1)
                                border.width: isDefault ? 1.5 : 1

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Column {
                                    id: devContent
                                    anchors {
                                        left: parent.left; right: parent.right
                                        top: parent.top
                                        leftMargin: Theme.spacingM; rightMargin: Theme.spacingM
                                        topMargin: Theme.spacingM
                                    }
                                    spacing: Theme.spacingXS

                                    // Name row: radio + icon + name + mute-line-through icon + mute btn
                                    RowLayout {
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        // Radio circle
                                        Rectangle {
                                            width: 18; height: 18
                                            radius: 9
                                            color: "transparent"
                                            border.color: isDefault ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.5)
                                            border.width: isDefault ? 2 : 1.5
                                            Layout.alignment: Qt.AlignVCenter

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 10; height: 10
                                                radius: 5
                                                color: Theme.primary
                                                visible: isDefault
                                            }
                                        }

                                        // Device type icon
                                        EHIcon {
                                            name: {
                                                const n = modelData?.name || ""
                                                if (n.includes("bluez") || n.includes("bluetooth")) return "headphones"
                                                if (n.includes("usb"))   return "usb"
                                                if (n.includes("hdmi"))  return "tv"
                                                return "laptop_mac"
                                            }
                                            size: Theme.iconSize
                                            color: isDefault ? Theme.primary : Theme.surfaceTextMedium
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        // Device name + description
                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            StyledText {
                                                text: AudioService.displayName(modelData)
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: isDefault ? Font.SemiBold : Font.Normal
                                                color: isDefault ? Theme.surfaceText : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }

                                        // Mute-strikethrough icon (shown when muted)
                                        EHIcon {
                                            name: "volume_off"
                                            size: Theme.iconSize - 2
                                            color: Theme.error
                                            visible: devMuted
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        // Mute button
                                        Rectangle {
                                            id: devMuteBtn
                                            width:  Theme.iconSize + Theme.spacingS * 2
                                            height: Theme.iconSize + Theme.spacingS * 2
                                            radius: height / 2
                                            Layout.alignment: Qt.AlignVCenter
                                            color: devMuteArea.containsMouse
                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            EHIcon {
                                                anchors.centerIn: parent
                                                name:  devMuted ? "volume_off" : "volume_up"
                                                size:  Theme.iconSize - 4
                                                color: devMuted ? Theme.error : Theme.primary
                                            }
                                            MouseArea {
                                                id: devMuteArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: { if (nodeAudio) nodeAudio.muted = !devMuted }
                                            }
                                        }
                                    }

                                    // Volume slider
                                    EHSlider {
                                        width:     parent.width
                                        minimum:   0
                                        maximum:   SettingsData.audioVolumeOverdrive ? 150 : 100
                                        value:     Math.round(devVolume * 100)
                                        showValue: true
                                        unit:      "%"
                                        enabled:   nodeAudio !== null && modelData.ready
                                        onSliderValueChanged: v => {
                                            if (nodeAudio && modelData.ready)
                                                nodeAudio.volume = v / 100.0
                                        }
                                    }
                                }

                                // Tap to select default device
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: AudioService.setAudioSink(modelData)
                                    // Pass through to child mouse areas
                                    z: -1
                                }
                            }
                        }
                    }

                    // ── INPUT DEVICES ─────────────────────────────────────────

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: AudioService.sources.length > 0

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingS

                            EHIcon {
                                name: "mic"
                                size: Theme.fontSizeMedium
                                color: Theme.primary
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledText {
                                text: "Input"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.SemiBold
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // Input master mute button
                            Rectangle {
                                width:  Theme.iconSize + Theme.spacingS * 2
                                height: Theme.iconSize + Theme.spacingS * 2
                                radius: height / 2
                                Layout.alignment: Qt.AlignVCenter
                                color: inputMasterMuteArea.containsMouse
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                Behavior on color { ColorAnimation { duration: 100 } }

                                EHIcon {
                                    anchors.centerIn: parent
                                    name:  AudioService.inputMuted ? "mic_off" : "mic"
                                    size:  Theme.iconSize - 4
                                    color: AudioService.inputMuted ? Theme.error : Theme.primary
                                }
                                MouseArea {
                                    id: inputMasterMuteArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        AudioService.suppressInputOSD()
                                        AudioService.setInputMuted(!AudioService.inputMuted)
                                    }
                                }
                            }
                        }

                        // Input master slider
                        EHSlider {
                            width:     parent.width
                            minimum:   0
                            maximum:   SettingsData.audioVolumeOverdrive ? 150 : 100
                            value:     Math.round(AudioService.inputVolume * 100)
                            showValue: true
                            unit:      "%"
                            leftIcon:  "mic"
                            onSliderValueChanged: v => {
                                AudioService.suppressInputOSD()
                                AudioService.setInputVolume(v / 100.0)
                            }
                        }
                    }

                    // ── Divider ───────────────────────────────────────────────

                    Rectangle {
                        width:  parent.width
                        height: 1
                        color:  Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    }

                    // ── APPLICATIONS ──────────────────────────────────────────

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        RowLayout {
                            width: parent.width
                            StyledText {
                                text: "Apps"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.SemiBold
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledText {
                                text: ApplicationAudioService.applicationStreams.length + " active"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        // Empty state
                        Item {
                            width:   parent.width
                            height:  emptyRow.implicitHeight + Theme.spacingM * 2
                            visible: ApplicationAudioService.applicationStreams.length === 0
                            Row {
                                id: emptyRow
                                anchors.centerIn: parent
                                spacing: Theme.spacingS
                                EHIcon { name: "volume_off"; size: Theme.fontSizeMedium; color: Theme.surfaceTextMedium; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: "No applications playing audio"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceTextMedium; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }

                        // App rows
                        Repeater {
                            model: ApplicationAudioService.applicationStreams

                            delegate: Rectangle {
                                id: appDelegate
                                required property PwNode modelData

                                property PwNodeAudio nodeAudio: modelData?.audio ?? null
                                property real  appVolume: nodeAudio?.volume ?? 0
                                property bool  appMuted:  nodeAudio?.muted  ?? false

                                // Per-app expanded state
                                property bool expanded: false

                                // Device routing state: null = system default, or a PwNode
                                property var  routedSink: null
                                property bool multiMode:  false
                                property var  multiSinks: []   // list of PwNode

                                PwObjectTracker { objects: modelData ? [modelData] : [] }

                                width:  flickable.width
                                height: appContent.implicitHeight + Theme.spacingM * 2
                                radius: Theme.widgetRadius
                                color: appHover.containsMouse && !expanded
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.07)
                                    : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.18)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, expanded ? 0.18 : 0.1)
                                border.width: expanded ? 1.5 : 1
                                clip: true
                                Behavior on color  { ColorAnimation { duration: 100 } }
                                Behavior on height { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

                                MouseArea { id: appHover; anchors.fill: parent; hoverEnabled: true }

                                Column {
                                    id: appContent
                                    anchors {
                                        left:   parent.left;  right:  parent.right
                                        top:    parent.top
                                        leftMargin:  Theme.spacingM
                                        rightMargin: Theme.spacingM
                                        topMargin:   Theme.spacingM
                                    }
                                    spacing: Theme.spacingXS

                                    // ── App header row ────────────────────────
                                    RowLayout {
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        // Drag handle (3-line icon)
                                        EHIcon {
                                            name: "drag_indicator"
                                            size: Theme.iconSize - 4
                                            color: Qt.rgba(Theme.surfaceTextMedium.r, Theme.surfaceTextMedium.g, Theme.surfaceTextMedium.b, 0.5)
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        // App icon
                                        Item {
                                            width:  Theme.iconSize
                                            height: Theme.iconSize
                                            Layout.alignment: Qt.AlignVCenter
                                            Image {
                                                anchors.fill: parent
                                                source:       ApplicationAudioService.getApplicationIcon(modelData)
                                                sourceSize:   Qt.size(Theme.iconSize * 2, Theme.iconSize * 2)
                                                smooth: true; mipmap: true
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                            }
                                            EHIcon {
                                                anchors.fill: parent
                                                name:    "apps"
                                                size:    Theme.iconSize
                                                color:   Theme.primary
                                                visible: parent.children[0].status !== Image.Ready
                                            }
                                        }

                                        // App name
                                        StyledText {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            text:           ApplicationAudioService.getApplicationName(modelData)
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight:    Font.Medium
                                            color:          Theme.surfaceText
                                            elide:          Text.ElideRight
                                        }

                                        // Volume slider + value (inline, compact)
                                        EHSlider {
                                            Layout.preferredWidth: 110
                                            Layout.alignment: Qt.AlignVCenter
                                            minimum:   0
                                            maximum:   SettingsData.audioVolumeOverdrive ? 150 : 100
                                            value:     Math.round(appVolume * 100)
                                            showValue: true
                                            unit:      "%"
                                            enabled:   nodeAudio !== null && modelData.ready
                                            onSliderValueChanged: v => {
                                                if (nodeAudio && modelData.ready)
                                                    nodeAudio.volume = v / 100.0
                                            }
                                        }

                                        // Waveform / activity indicator (2 small bars)
                                        Row {
                                            spacing: 2
                                            Layout.alignment: Qt.AlignVCenter
                                            Repeater {
                                                model: 2
                                                Rectangle {
                                                    width: 3
                                                    height: (index === 0 ? 10 : 6) * (appMuted ? 0.3 : 1)
                                                    radius: 2
                                                    color: appMuted ? Theme.error : Theme.primary
                                                    anchors.verticalCenter: parent?.verticalCenter
                                                    Behavior on height { NumberAnimation { duration: 300 } }
                                                }
                                            }
                                        }

                                        // Device picker button
                                        Rectangle {
                                            id: devicePickerBtn
                                            Layout.alignment: Qt.AlignVCenter
                                            height: Theme.iconSize + Theme.spacingS * 2
                                            width:  devicePickerRow.implicitWidth + Theme.spacingM * 2
                                            radius: height / 2
                                            color: devicePickerBtnArea.containsMouse
                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Row {
                                                id: devicePickerRow
                                                anchors.centerIn: parent
                                                spacing: 4

                                                EHIcon {
                                                    name: {
                                                        if (appDelegate.multiMode && appDelegate.multiSinks.length > 1) return "speaker_group"
                                                        if (appDelegate.routedSink) {
                                                            const n = appDelegate.routedSink.name || ""
                                                            if (n.includes("bluez")) return "headphones"
                                                            return "speaker"
                                                        }
                                                        return "language"
                                                    }
                                                    size: Theme.iconSize - 4
                                                    color: Theme.primary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                StyledText {
                                                    text: {
                                                        if (appDelegate.multiMode && appDelegate.multiSinks.length > 1)
                                                            return appDelegate.multiSinks.length + " devices"
                                                        if (appDelegate.routedSink)
                                                            return AudioService.displayName(appDelegate.routedSink).substring(0, 8) + "…"
                                                        return "System…"
                                                    }
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    color: Theme.primary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                EHIcon {
                                                    name: appDelegate.expanded ? "expand_less" : "expand_more"
                                                    size: Theme.iconSize - 6
                                                    color: Theme.primary
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: devicePickerBtnArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: appDelegate.expanded = !appDelegate.expanded
                                            }
                                        }

                                        // Mute button
                                        Rectangle {
                                            id: appMuteBtn
                                            width:  Theme.iconSize + Theme.spacingS * 2
                                            height: Theme.iconSize + Theme.spacingS * 2
                                            radius: height / 2
                                            Layout.alignment: Qt.AlignVCenter
                                            color: appMuteArea.containsMouse
                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            EHIcon {
                                                anchors.centerIn: parent
                                                name:    appMuted ? "volume_off" : "volume_up"
                                                size:    Theme.iconSize - 4
                                                color:   appMuted ? Theme.error : Theme.primary
                                                opacity: (nodeAudio !== null && modelData.ready) ? 1 : 0.3
                                            }
                                            MouseArea {
                                                id: appMuteArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape:  Qt.PointingHandCursor
                                                enabled:      nodeAudio !== null && modelData.ready
                                                onClicked:    nodeAudio.muted = !appMuted
                                            }
                                        }
                                    }

                                    // ── Expanded panel: device routing ────────
                                    Rectangle {
                                        width:   parent.width
                                        visible: appDelegate.expanded
                                        height:  appDelegate.expanded ? routingPanel.implicitHeight + Theme.spacingM * 2 : 0
                                        radius:  Theme.widgetRadius - 2
                                        color:   Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                                        border.width: 1
                                        clip: true

                                        Behavior on height { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing } }

                                        Column {
                                            id: routingPanel
                                            anchors {
                                                left: parent.left; right: parent.right; top: parent.top
                                                margins: Theme.spacingM
                                            }
                                            spacing: Theme.spacingS

                                            // Single / Multi toggle
                                            RowLayout {
                                                width: parent.width

                                                StyledText {
                                                    text: "Output routing"
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.Medium
                                                    color: Theme.surfaceTextMedium
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                }

                                                EHButtonGroup {
                                                    model: ["Single", "Multi"]
                                                    currentIndex: appDelegate.multiMode ? 1 : 0
                                                    buttonHeight: 28
                                                    minButtonWidth: 52
                                                    textSize: Theme.fontSizeSmall
                                                    Layout.alignment: Qt.AlignVCenter
                                                    onSelectionChanged: (idx, sel) => {
                                                        if (idx === 1 && sel) {
                                                            appDelegate.multiMode = true
                                                        } else if (idx === 0 && sel) {
                                                            appDelegate.multiMode = false
                                                            appDelegate.multiSinks = []
                                                        }
                                                    }
                                                }
                                            }

                                            // Device list with checkboxes (multi) or radio (single)
                                            Repeater {
                                                model: AudioService.sinks

                                                delegate: Rectangle {
                                                    required property PwNode modelData
                                                    required property int index

                                                    property bool isSysDefault: AudioService.sink === modelData
                                                    property bool isChecked: {
                                                        if (appDelegate.multiMode) {
                                                            return appDelegate.multiSinks.indexOf(modelData) >= 0
                                                        } else {
                                                            return appDelegate.routedSink === modelData || (!appDelegate.routedSink && isSysDefault)
                                                        }
                                                    }

                                                    width: parent.width
                                                    height: 36
                                                    radius: Theme.widgetRadius - 2
                                                    color: routeItemArea.containsMouse
                                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                                        : "transparent"
                                                    Behavior on color { ColorAnimation { duration: 80 } }

                                                    RowLayout {
                                                        anchors { fill: parent; leftMargin: Theme.spacingS; rightMargin: Theme.spacingS }
                                                        spacing: Theme.spacingS

                                                        // Checkbox or radio
                                                        Rectangle {
                                                            width: 16; height: 16
                                                            radius: appDelegate.multiMode ? 3 : 8
                                                            color: isChecked
                                                                ? Theme.primary
                                                                : "transparent"
                                                            border.color: isChecked
                                                                ? Theme.primary
                                                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.5)
                                                            border.width: isChecked ? 0 : 1.5
                                                            Layout.alignment: Qt.AlignVCenter

                                                            EHIcon {
                                                                anchors.centerIn: parent
                                                                name: "check"
                                                                size: 12
                                                                color: Theme.onPrimary
                                                                visible: isChecked && appDelegate.multiMode
                                                            }

                                                            Rectangle {
                                                                anchors.centerIn: parent
                                                                width: 8; height: 8; radius: 4
                                                                color: Theme.onPrimary
                                                                visible: isChecked && !appDelegate.multiMode
                                                            }
                                                        }

                                                        // Device icon
                                                        EHIcon {
                                                            name: {
                                                                const n = modelData?.name || ""
                                                                if (n.includes("bluez")) return "headphones"
                                                                if (n.includes("hdmi"))  return "tv"
                                                                return "laptop_mac"
                                                            }
                                                            size: Theme.iconSize - 2
                                                            color: isChecked ? Theme.primary : Theme.surfaceTextMedium
                                                            Layout.alignment: Qt.AlignVCenter
                                                        }

                                                        StyledText {
                                                            text: AudioService.displayName(modelData)
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: isChecked ? Theme.surfaceText : Theme.surfaceTextMedium
                                                            font.weight: isChecked ? Font.Medium : Font.Normal
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                            Layout.alignment: Qt.AlignVCenter
                                                        }

                                                        // Star / default marker
                                                        EHIcon {
                                                            name: "star"
                                                            size: Theme.iconSize - 4
                                                            color: Theme.primary
                                                            visible: isSysDefault
                                                            Layout.alignment: Qt.AlignVCenter
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: routeItemArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (appDelegate.multiMode) {
                                                                const idx = appDelegate.multiSinks.indexOf(modelData)
                                                                let arr = [...appDelegate.multiSinks]
                                                                if (idx >= 0) arr.splice(idx, 1)
                                                                else arr.push(modelData)
                                                                appDelegate.multiSinks = arr
                                                            } else {
                                                                appDelegate.routedSink = modelData
                                                                ApplicationAudioService.routeStreamToOutput(appDelegate.modelData, modelData)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: root.close()
        }
    }
}
