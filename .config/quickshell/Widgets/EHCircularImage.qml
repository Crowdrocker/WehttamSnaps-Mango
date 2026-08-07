import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string imageSource: ""
    property string fallbackIcon: "notifications"
    property string fallbackText: ""
    property bool hasImage: filteredImageSource !== ""
    property alias imageStatus: internalImage.status

    readonly property string filteredImageSource: {
        if (!imageSource) return ""

        // Allow all browser cache files - Cider and other apps cache album art here
        // These are already vetted by EHAlbumArt.resolveArtUrl() before reaching here
        
        // Allow /tmp/ and /var/tmp/ paths for music thumbnails and other content
        return imageSource
    }

    radius: width / 2
    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
    border.color: "transparent"
    border.width: 0

    Image {
        id: internalImage
        anchors.fill: parent
        anchors.margins: 2
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        cache: true
        visible: false
        source: root.filteredImageSource

        Component.onCompleted: {
            sourceSize.width = 128
            sourceSize.height = 128
        }

        onStatusChanged: {
            if (status === Image.Error) {
                if (!source.toString().includes(".org.chromium.") &&
                    !source.toString().includes("/tmp/") &&
                    !source.toString().includes("/var/tmp/")) {
                    console.warn("EHCircularImage: Failed to load image:", source)
                }
            }
        }
    }

    MultiEffect {
        anchors.fill: parent
        anchors.margins: 2
        source: internalImage
        maskEnabled: true
        maskSource: circularMask
        visible: internalImage.status === Image.Ready && root.imageSource !== ""
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Item {
        id: circularMask
        width: parent.width - 4
        height: parent.height - 4
        anchors.centerIn: parent
        layer.enabled: true
        layer.smooth: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "black"
            antialiasing: true
        }
    }

    EHIcon {
        anchors.centerIn: parent
        name: root.fallbackIcon
        size: parent.width * 0.5
        color: Theme.surfaceVariantText
        visible: internalImage.status !== Image.Ready && root.imageSource === "" && root.fallbackIcon !== ""
    }


    StyledText {
        anchors.centerIn: parent
        visible: root.imageSource === "" && root.fallbackIcon === "" && root.fallbackText !== ""
        text: root.fallbackText
        font.pixelSize: Math.max(12, parent.width * 0.36)
        font.weight: Font.Bold
        color: Theme.primaryText
    }
}