import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    implicitHeight: headerRow.height + Theme.spacingS + audioColumn.implicitHeight + Theme.spacingM * 3
    clip:         true
    radius:       Theme.cornerRadius
    color:        Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1

    // ── App row component ─────────────────────────────────────────────────────

    Component {
        id: appRowComponent

        Rectangle {
            id: appRow

            property var  node:    null
            property bool isInput: false

            property PwNodeAudio nodeAudio: node?.audio ?? null
            property real  appVolume: nodeAudio?.volume ?? 0
            property bool  appMuted:  nodeAudio?.muted  ?? false

            PwObjectTracker { objects: appRow.node ? [appRow.node] : [] }

            width:  parent ? parent.width : 0
            height: appContent.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: rowHover.containsMouse
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.07)
                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.18)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 100 } }

            MouseArea { id: rowHover; anchors.fill: parent; hoverEnabled: true }

            Column {
                id: appContent
                anchors {
                    left:        parent.left
                    right:       parent.right
                    leftMargin:  Theme.spacingM
                    rightMargin: Theme.spacingM + muteBtn.width + 2
                    top:         parent.top
                    topMargin:   Theme.spacingM
                }
                spacing: Theme.spacingXS

                // Icon + name
                Row {
                    width:   parent.width
                    spacing: Theme.spacingS

                    Item {
                        width:  Theme.iconSize
                        height: Theme.iconSize
                        anchors.verticalCenter: parent.verticalCenter

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

                    StyledText {
                        width:          parent.width - Theme.iconSize - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text:           ApplicationAudioService.getApplicationName(appRow.node)
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight:    Font.Medium
                        color:          Theme.surfaceText
                        elide:          Text.ElideRight
                    }
                }

                // Slider
                EHSlider {
                    width:     parent.width
                    minimum:   0
                    maximum:   SettingsData.audioVolumeOverdrive ? 150 : 100
                    value:     Math.round(appVolume * 100)
                    showValue: true
                    unit:      "%"
                    enabled:   nodeAudio !== null && appRow.node?.ready !== false
                    onSliderValueChanged: v => {
                        if (!nodeAudio || appRow.node?.ready === false) return
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
                anchors {
                    right:          parent.right
                    rightMargin:    Theme.spacingM
                    verticalCenter: appContent.verticalCenter
                }
                color: muteBtnArea.containsMouse
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                Behavior on color { ColorAnimation { duration: 100 } }

                EHIcon {
                    anchors.centerIn: parent
                    name:    appRow.appMuted
                                ? (appRow.isInput ? "mic_off"  : "volume_off")
                                : (appRow.isInput ? "mic"      : "volume_up")
                    size:    Theme.iconSize - 4
                    color:   appRow.appMuted ? Theme.error : Theme.primary
                    opacity: (nodeAudio !== null && appRow.node?.ready !== false) ? 1 : 0.3
                }

                MouseArea {
                    id: muteBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    enabled:      nodeAudio !== null && appRow.node?.ready !== false
                    onClicked:    appRow.isInput
                        ? ApplicationAudioService.toggleApplicationInputMute(appRow.node)
                        : ApplicationAudioService.toggleApplicationMute(appRow.node)
                }
            }
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────

    RowLayout {
        id: headerRow
        anchors {
            left:    parent.left
            right:   parent.right
            top:     parent.top
            margins: Theme.spacingM
        }
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
            font.weight:      Font.SemiBold
            color:            Theme.surfaceText
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        // Settings gear button — pinned top-right
        Rectangle {
            id: settingsBtn
            width:  Theme.iconSize + Theme.spacingS * 2
            height: Theme.iconSize + Theme.spacingS * 2
            radius: height / 2
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            color: settingsBtnArea.containsMouse
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
            Behavior on color { ColorAnimation { duration: 100 } }

            EHIcon {
                anchors.centerIn: parent
                name:  "settings"
                size:  Theme.iconSize - 4
                color: Theme.primary
            }

            MouseArea {
                id: settingsBtnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked:    root.settingsRequested()
            }
        }
    }

    signal settingsRequested()

    // ── Scrollable content ────────────────────────────────────────────────────

    EHFlickable {
        id: audioContent
        anchors {
            top:         headerRow.bottom
            left:        parent.left
            right:       parent.right
            bottom:      parent.bottom
            leftMargin:  Theme.spacingM
            rightMargin: Theme.spacingM
            topMargin:   Theme.spacingS
            bottomMargin: Theme.spacingM
        }
        contentHeight: audioColumn.implicitHeight
        clip: true

        Column {
            id: audioColumn
            width:   parent.width
            spacing: Theme.spacingS

            // ── Output section ────────────────────────────────────────────────

            Column {
                width:   parent.width
                spacing: Theme.spacingS
                visible: (ApplicationAudioService.applicationStreams || []).length > 0

                Row {
                    spacing: Theme.spacingS

                    EHIcon {
                        name:  "volume_up"
                        size:  Theme.fontSizeSmall
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text:           "Output"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight:    Font.Medium
                        color:          Theme.surfaceTextMedium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Repeater {
                    model: ApplicationAudioService.applicationStreams || []
                    delegate: Loader {
                        width:  audioColumn.width
                        height: item ? item.height : 0
                        sourceComponent: appRowComponent
                        onLoaded: {
                            if (!modelData) return
                            item.node    = modelData
                            item.isInput = false
                        }
                    }
                }
            }

            // ── Divider ───────────────────────────────────────────────────────

            Rectangle {
                width:   parent.width
                height:  1
                color:   Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                visible: (ApplicationAudioService.applicationStreams       || []).length > 0 &&
                         (ApplicationAudioService.applicationInputStreams  || []).length > 0
            }

            // ── Input section ─────────────────────────────────────────────────

            Column {
                width:   parent.width
                spacing: Theme.spacingS
                visible: (ApplicationAudioService.applicationInputStreams || []).length > 0

                Row {
                    spacing: Theme.spacingS

                    EHIcon {
                        name:  "mic"
                        size:  Theme.fontSizeSmall
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text:           "Input"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight:    Font.Medium
                        color:          Theme.surfaceTextMedium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Repeater {
                    model: ApplicationAudioService.applicationInputStreams || []
                    delegate: Loader {
                        width:  audioColumn.width
                        height: item ? item.height : 0
                        sourceComponent: appRowComponent
                        onLoaded: {
                            if (!modelData) return
                            item.node    = modelData
                            item.isInput = true
                        }
                    }
                }
            }

            // ── Empty state ───────────────────────────────────────────────────

            Item {
                width:   parent.width
                height:  emptyRow.implicitHeight + Theme.spacingM * 2
                visible: (ApplicationAudioService.applicationStreams      || []).length === 0 &&
                         (ApplicationAudioService.applicationInputStreams || []).length === 0

                Row {
                    id: emptyRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    EHIcon {
                        name:  "volume_off"
                        size:  Theme.fontSizeMedium
                        color: Theme.surfaceTextMedium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text:           "No applications with audio"
                        font.pixelSize: Theme.fontSizeSmall
                        color:          Theme.surfaceTextMedium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
