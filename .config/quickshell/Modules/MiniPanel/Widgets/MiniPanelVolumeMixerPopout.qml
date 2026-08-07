import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

EHPopout {
    id: root
    objectName: "volumeMixerPopout"

    property string triggerSection: "right"
    property var triggerScreen: null

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX = x;
        triggerY = y;
        triggerWidth = width;
        triggerSection = section;
        triggerScreen = screen;
    }

    // Bar-aware positioning properties
    readonly property string barPosition: typeof SettingsData !== "undefined" ? SettingsData.minipanelPosition : "top"
    readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
    readonly property bool barFloating: typeof SettingsData !== "undefined" ? SettingsData.minipanelFloat : false
    readonly property bool barVisible: typeof SettingsData !== "undefined" ? SettingsData.showMiniPanel : true
    readonly property real barMarginH: barFloating ? SettingsData.minipanelMarginHorizontal : 0
    readonly property real barMarginV: barFloating ? SettingsData.minipanelMarginVertical : 0
    readonly property real attachmentOverlap: 1 // Panel extends 1px into bar area to fix hairline gap
    readonly property real barHeight: typeof SettingsData !== "undefined" ? SettingsData.minipanelHeight : Theme.barHeight
    // Bar thickness includes spacing and is the actual visual thickness of the bar (matches EHPopout pattern)
    readonly property real barThickness: (typeof SettingsData !== "undefined" && barVisible && !barFloating) ? 
        (SettingsData.minipanelHeight + SettingsData.minipanelSpacing + (SettingsData.minipanelGothCornersEnabled ? Theme.widgetRadius : 0)) : 0

    popupWidth: 400
    popupHeight: contentLoader.item ? contentLoader.item.implicitHeight : 400
    triggerWidth: 70
    screen: triggerScreen
    shouldBeVisible: false
    visible: shouldBeVisible

    content: Component {
        Rectangle {
            id: volumeContent

            implicitHeight: contentColumn.implicitHeight + Theme.spacingL * 2
            color: Theme.popupBackground()
            radius: Theme.widgetRadius
            border.color: Theme.outlineMedium
            border.width: 1
            antialiasing: true
            smooth: true
            focus: true
            Component.onCompleted: {
                if (root.shouldBeVisible) {
                    forceActiveFocus();
                }
            }
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }

            Connections {
                function onShouldBeVisibleChanged() {
                    if (root.shouldBeVisible) {
                        Qt.callLater(function() {
                            volumeContent.forceActiveFocus();
                        });
                    }
                }
                target: root
            }

            // Shadow layers
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                color: "transparent"
                radius: parent.radius + 3
                border.color: Theme.outlineLight
                border.width: 1
                z: -3
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                color: "transparent"
                radius: parent.radius + 2
                border.color: Theme.shadowMedium
                border.width: 1
                z: -2
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Theme.outlineStrong
                border.width: 1
                radius: parent.radius
                z: -1
            }

            ColumnLayout {
                id: contentColumn
                width: parent.width - Theme.spacingL * 2
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                // System Volume Controls
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: systemVolumeRow.implicitHeight + Theme.spacingL * 2
                    radius: Theme.widgetRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.3)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: 1

                    RowLayout {
                        id: systemVolumeRow
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        spacing: Theme.spacingM

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.spacingXS

                            RowLayout {
                                spacing: Theme.spacingXS

                                StyledText {
                                    text: "System Volume"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: AudioService.muted ? Theme.error : "white"
                                    font.weight: Font.Medium
                                }

                                StyledText {
                                    text: AudioService.sink ? (" - " + AudioService.displayName(AudioService.sink)) : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: "white"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            EHSlider {
                                Layout.fillWidth: true
                                minimum: 0
                                maximum: SettingsData.audioVolumeOverdrive ? 150 : 100
                                value: Math.round(AudioService.volume * 100)
                                showValue: true
                                unit: "%"
                                onSliderValueChanged: function(newValue) {
                                    AudioService.suppressOutputOSD();
                                    AudioService.setVolume(newValue / 100.0);
                                }
                            }
                        }

                        Rectangle {
                            width: Theme.iconSize + Theme.spacingS * 2
                            height: Theme.iconSize + Theme.spacingS * 2
                            radius: (Theme.iconSize + Theme.spacingS * 2) / 2
                            color: muteArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                            MouseArea {
                                id: muteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    AudioService.suppressOutputOSD();
                                    AudioService.setOutputMuted(!AudioService.muted);
                                }
                            }

                            EHIcon {
                                anchors.centerIn: parent
                                name: AudioService.getOutputIcon()
                                size: Theme.iconSize
                                color: AudioService.muted ? Theme.error : Theme.primary
                            }
                        }
                    }
                }

                // Application Streams
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Applications"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: "white"
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: `${ApplicationAudioService.applicationStreams.length} active`
                            font.pixelSize: Theme.fontSizeSmall
                            color: "white"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    }

                    // Application volume controls
                    Repeater {
                        model: ApplicationAudioService.applicationStreams

                        delegate: Rectangle {
                            required property PwNode modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: appRow.implicitHeight + Theme.spacingM * 2
                            radius: Theme.widgetRadius
                            color: appArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                            border.width: 1

                            // Track individual node to ensure properties are bound
                            PwObjectTracker {
                                objects: modelData ? [modelData] : []
                            }

                            // Define audio properties
                            property PwNodeAudio nodeAudio: (modelData && modelData.audio) ? modelData.audio : null
                            property real appVolume: (nodeAudio && nodeAudio.volume !== undefined) ? nodeAudio.volume : 0.0
                            property bool appMuted: (nodeAudio && nodeAudio.muted !== undefined) ? nodeAudio.muted : false

                            MouseArea {
                                id: appArea
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            RowLayout {
                                id: appRow
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                // App Icon
                                Image {
                                    Layout.preferredWidth: Theme.iconSize
                                    Layout.preferredHeight: Theme.iconSize
                                    Layout.alignment: Qt.AlignHCenter
                                    source: ApplicationAudioService.getApplicationIcon(modelData)
                                        sourceSize.width: Theme.iconSize * 2
                                        sourceSize.height: Theme.iconSize * 2
                                    smooth: true
                                    mipmap: true
                                    fillMode: Image.PreserveAspectFit
                                    cache: true
                                    asynchronous: true

                                    EHIcon {
                                        anchors.fill: parent
                                        name: "apps"
                                        size: Theme.iconSize
                                        color: Theme.primary
                                        visible: parent.status === Image.Error || parent.status === Image.Null || parent.source === ""
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: ApplicationAudioService.getApplicationName(modelData)
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: "white"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    EHSlider {
                                        Layout.fillWidth: true
                                        minimum: 0
                                        maximum: SettingsData.audioVolumeOverdrive ? 150 : 100
                                        value: Math.round(appVolume * 100)
                                        showValue: true
                                        unit: "%"
                                        enabled: nodeAudio && modelData.ready
                                        onSliderValueChanged: function(newValue) {
                                            if (nodeAudio && modelData.ready) {
                                                nodeAudio.volume = newValue / 100.0;
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: Theme.iconSize + Theme.spacingS * 2
                                    Layout.preferredHeight: Theme.iconSize + Theme.spacingS * 2
                                    Layout.alignment: Qt.AlignBottom
                                    radius: (Theme.iconSize + Theme.spacingS * 2) / 2
                                    color: appMuteArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                                    MouseArea {
                                        id: appMuteArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: nodeAudio && modelData.ready
                                        onClicked: {
                                            if (nodeAudio && modelData.ready) {
                                                nodeAudio.muted = !appMuted;
                                            }
                                        }
                                    }

                                    EHIcon {
                                        anchors.centerIn: parent
                                        name: appMuted ? "volume_off" : "volume_up"
                                        size: Theme.iconSize
                                        color: !appMuted ? Theme.primary : "white"
                                        opacity: (nodeAudio && modelData.ready) ? 1 : 0.3
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: Theme.widgetRadius
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.1)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                        border.width: 1
                        visible: ApplicationAudioService.applicationStreams.length === 0

                        StyledText {
                            text: "No applications with audio output"
                            font.pixelSize: Theme.fontSizeSmall
                            color: "white"
                            anchors.centerIn: parent
                        }
                    }
                }
            }
        }
    }
}