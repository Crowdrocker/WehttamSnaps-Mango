import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

Item {
    id: root

    property bool showInputs:  true
    property bool showOutputs: true
    property bool compact:     false

    implicitWidth:  parent.width
    implicitHeight: contentCol.implicitHeight

    // ── App card component ────────────────────────────────────────────────────

    Component {
        id: appRowComponent

        Rectangle {
            id: appRow

            property var  node:    null
            property bool isInput: false
            property bool compact: false

            property PwNodeAudio nodeAudio: node?.audio ?? null
            property real  appVolume: nodeAudio?.volume ?? 0
            property bool  appMuted:  nodeAudio?.muted  ?? false

            PwObjectTracker { objects: appRow.node ? [appRow.node] : [] }

            readonly property int mixerRowMinH: {
                let h = Math.max(76, Math.round(Theme.iconSize + Theme.spacingM * 2))
                return h + (h % 2)
            }

            width:  parent ? parent.width : 0
            height: mixerRowMinH
            radius: Theme.cornerRadius
            // Slightly elevated card — distinct from the outer widget background
            color: rowHover.containsMouse
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.09)
                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.22)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.13)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }

            MouseArea { id: rowHover; anchors.fill: parent; hoverEnabled: true }

            // Card inner layout — explicit vertical center in fixed row height (avoids 1px stagger)
            RowLayout {
                id: cardContent
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                height:                 parent.height - Theme.spacingM * 2
                anchors.leftMargin:     Theme.spacingM
                anchors.rightMargin:    Theme.spacingM
                spacing:                Theme.spacingS

                // App icon
                Item {
                    width:  Theme.iconSize
                    height: Theme.iconSize
                    Layout.alignment: Qt.AlignVCenter
                    transform: Translate { y: 2 }

                    Image {
                        anchors.fill: parent
                        source:       ApplicationAudioService.getApplicationIcon(appRow.node)
                        sourceSize:   Qt.size(Theme.iconSize * 2, Theme.iconSize * 2)
                        smooth:       true
                        mipmap:       true
                        fillMode:     Image.PreserveAspectFit
                        asynchronous: true
                    }
                    EHIcon {
                        anchors.fill: parent
                        name:    appRow.isInput ? "mic" : "apps"
                        size:    Theme.iconSize
                        color:   Theme.primary
                        visible: parent.children[0].status !== Image.Ready
                    }
                }

                // Name + slider stacked
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.spacingXS

                    StyledText {
                        width:          parent.width
                        text:           ApplicationAudioService.getApplicationName(appRow.node)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight:    Font.Medium
                        color:          Theme.surfaceText
                        elide:          Text.ElideRight
                    }

                    EHSlider {
                        width:     parent.width
                        minimum:   0
                        maximum:   SettingsData.audioVolumeOverdrive ? 150 : 100
                        value:     Math.round(appVolume * 100)
                        showValue: !appRow.compact
                        unit:      "%"
                        enabled:   nodeAudio !== null && appRow.node !== null && appRow.node.ready
                        onSliderValueChanged: v => {
                            if (!nodeAudio || !appRow.node?.ready) return
                            appRow.isInput
                                ? ApplicationAudioService.setApplicationInputVolume(appRow.node, v)
                                : ApplicationAudioService.setApplicationVolume(appRow.node, v)
                        }
                    }
                }

                // Mute button
                Rectangle {
                    id: muteBtn
                    width:  Theme.iconSize + Theme.spacingS * 2
                    height: Theme.iconSize + Theme.spacingS * 2
                    radius: height / 2
                    Layout.alignment: Qt.AlignVCenter
                    transform: Translate { y: 2 }
                    color: muteBtnArea.containsMouse
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                        : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.09)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    EHIcon {
                        anchors.centerIn: parent
                        name:    appRow.appMuted
                                    ? (appRow.isInput ? "mic_off"    : "volume_off")
                                    : (appRow.isInput ? "mic"        : "volume_up")
                        size:    Theme.iconSize - 4
                        color:   appRow.appMuted ? Theme.error : Theme.primary
                        opacity: (nodeAudio !== null && appRow.node?.ready) ? 1 : 0.3
                    }

                    MouseArea {
                        id: muteBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        enabled:      nodeAudio !== null && appRow.node?.ready
                        onClicked:    appRow.isInput
                            ? ApplicationAudioService.toggleApplicationInputMute(appRow.node)
                            : ApplicationAudioService.toggleApplicationMute(appRow.node)
                    }
                }
            }
        }
    }

    // ── Content ───────────────────────────────────────────────────────────────

    Column {
        id: contentCol
        width:   parent.width
        spacing: Theme.spacingM

        // ── Header ────────────────────────────────────────────────────────────

        RowLayout {
            width: parent.width
            spacing: Theme.spacingS

            EHIcon {
                name:  "tune"
                size:  Theme.fontSizeMedium
                color: Theme.primary
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                text:             "Volume Mixer"
                font.pixelSize:   Theme.fontSizeMedium
                font.weight:      600
                color:            Theme.surfaceText
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            Row {
                spacing: Theme.spacingXS
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: [
                        { label: "Output", get: () => root.showOutputs, set: () => root.showOutputs = !root.showOutputs },
                        { label: "Input",  get: () => root.showInputs,  set: () => root.showInputs  = !root.showInputs  }
                    ]

                    Rectangle {
                        required property var modelData
                        readonly property bool active: modelData.get()
                        width:  pillLbl.implicitWidth + Theme.spacingM * 2
                        height: pillLbl.implicitHeight + Theme.spacingXS * 2
                        radius: height / 2
                        color:  active
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                            : Qt.rgba(Theme.outline.r,  Theme.outline.g,  Theme.outline.b,  0.12)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        StyledText {
                            id: pillLbl
                            anchors.centerIn: parent
                            text:           modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight:    active ? Font.Medium : Font.Normal
                            color:          active ? Theme.primary : Theme.surfaceTextMedium
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    modelData.set()
                        }
                    }
                }
            }
        }

        // ── Output streams ────────────────────────────────────────────────────

        Column {
            width:   parent.width
            spacing: Theme.spacingS
            visible: root.showOutputs

            // Section label
            StyledText {
                visible:        !root.compact
                text:           "Output"
                font.pixelSize: Theme.fontSizeXSmall
                font.weight:    Font.Medium
                color:          Theme.surfaceTextMedium
                leftPadding:    2
            }

            // Empty state
            Item {
                width:   parent.width
                height:  noOutRow.implicitHeight + Theme.spacingS * 2
                visible: (ApplicationAudioService.applicationStreams || []).length === 0

                RowLayout {
                    id: noOutRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingS
                    EHIcon {
                        name: "volume_off"
                        size: Theme.fontSizeMedium
                        color: Theme.surfaceTextMedium
                        Layout.alignment: Qt.AlignVCenter
                    }
                    StyledText {
                        text: "No output applications"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        Layout.alignment: Qt.AlignVCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Stream cards — each app gets its own card
            Repeater {
                model: ApplicationAudioService.applicationStreams || []
                delegate: Loader {
                    width:  contentCol.width
                    height: item ? item.height : 0
                    sourceComponent: appRowComponent
                    onLoaded: {
                        if (!modelData) return
                        item.node    = modelData
                        item.isInput = false
                        item.compact = root.compact
                    }
                }
            }
        }

        // ── Input streams ─────────────────────────────────────────────────────

        Column {
            width:   parent.width
            spacing: Theme.spacingS
            visible: root.showInputs

            // Divider between output and input sections
            Rectangle {
                width:   parent.width
                height:  1
                color:   Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)
                visible: root.showOutputs
            }

            Item {
                width:  parent.width
                height: (root.showOutputs && root.showInputs) ? 4 : 0
            }

            // Section label
            StyledText {
                visible:        !root.compact
                text:           "Input"
                font.pixelSize: Theme.fontSizeXSmall
                font.weight:    Font.Medium
                color:          Theme.surfaceTextMedium
                leftPadding:    2
            }

            // Empty state
            Item {
                width:   parent.width
                height:  noInRow.implicitHeight + Theme.spacingS * 2
                visible: (ApplicationAudioService.applicationInputStreams || []).length === 0

                RowLayout {
                    id: noInRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingS
                    EHIcon {
                        name: "mic_off"
                        size: Theme.fontSizeMedium
                        color: Theme.surfaceTextMedium
                        Layout.alignment: Qt.AlignVCenter
                    }
                    StyledText {
                        text: "No input applications"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        Layout.alignment: Qt.AlignVCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Stream cards — each input app gets its own card
            Repeater {
                model: ApplicationAudioService.applicationInputStreams || []
                delegate: Loader {
                    width:  contentCol.width
                    height: item ? item.height : 0
                    sourceComponent: appRowComponent
                    onLoaded: {
                        if (!modelData) return
                        item.node    = modelData
                        item.isInput = true
                        item.compact = root.compact
                    }
                }
            }
        }
    }
}
