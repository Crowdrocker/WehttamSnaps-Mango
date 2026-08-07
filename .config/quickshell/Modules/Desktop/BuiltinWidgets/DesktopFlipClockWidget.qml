import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var instanceData: null
    property var screen: null
    property real widgetWidth: 200
    property real widgetHeight: 180

    readonly property var cfg: instanceData?.config ?? {}

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    // Component for flip digit card
    component FlipDigitCard: Item {
        id: flipDigit
        property string currentValue: "0"
        property string previousValue: "0"
        width: 40
        height: 56

        onCurrentValueChanged: {
            if (currentValue !== previousValue && previousValue !== "0") {
                flipAnimation.start()
            }
            previousValue = currentValue
        }

        Rectangle {
            id: cardBackground
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.6)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            border.width: 1
        }

        Item {
            id: flipContainer
            anchors.fill: parent
            anchors.margins: 4
            clip: true

            // Top half (flips up)
            Item {
                id: topHalf
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: parent.height / 2
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.8)
                    radius: Theme.cornerRadius
                }

                transform: Scale {
                    id: topScale
                    origin.y: flipContainer.height / 2
                    yScale: 1
                }

                StyledText {
                    anchors.horizontalCenter: flipContainer.horizontalCenter
                    anchors.verticalCenter: flipContainer.verticalCenter
                    text: flipDigit.previousValue !== "0" ? flipDigit.previousValue : flipDigit.currentValue
                    font.pixelSize: 40
                    color: Theme.primary
                    font.weight: Font.Medium
                    width: flipContainer.width
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Bottom half (shows current/new value)
            Item {
                id: bottomHalf
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height / 2
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.8)
                    radius: Theme.cornerRadius
                }

                StyledText {
                    anchors.horizontalCenter: flipContainer.horizontalCenter
                    anchors.verticalCenter: flipContainer.verticalCenter
                    text: flipDigit.currentValue
                    font.pixelSize: 40
                    color: Theme.primary
                    font.weight: Font.Medium
                    width: flipContainer.width
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Divider line
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }
        }

        SequentialAnimation {
            id: flipAnimation
            NumberAnimation {
                target: topScale
                property: "yScale"
                from: 1
                to: 0
                duration: 350
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: topScale
                property: "yScale"
                from: 0
                to: 1
                duration: 350
                easing.type: Easing.OutQuad
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, cfg.transparency !== undefined ? cfg.transparency : 0.2)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1

        Item {
            anchors.fill: parent
            anchors.margins: Theme.spacingM

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingM

                Row {
                    spacing: Theme.spacingXS
                    anchors.horizontalCenter: parent.horizontalCenter

                    FlipDigitCard {
                        id: hourTens
                        currentValue: {
                            if (SettingsData.use24HourClock) {
                                return String(systemClock?.date?.getHours()).padStart(2, '0').charAt(0)
                            } else {
                                const hours = systemClock?.date?.getHours()
                                const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours
                                return String(display).padStart(2, '0').charAt(0)
                            }
                        }
                    }
                    
                    FlipDigitCard {
                        id: hourOnes
                        currentValue: {
                            if (SettingsData.use24HourClock) {
                                return String(systemClock?.date?.getHours()).padStart(2, '0').charAt(1)
                            } else {
                                const hours = systemClock?.date?.getHours()
                                const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours
                                return String(display).padStart(2, '0').charAt(1)
                            }
                        }
                    }
                }
                
                Row {
                    spacing: Theme.spacingXS
                    anchors.horizontalCenter: parent.horizontalCenter

                    FlipDigitCard {
                        id: minuteTens
                        currentValue: String(systemClock?.date?.getMinutes()).padStart(2, '0').charAt(0)
                    }
                    
                    FlipDigitCard {
                        id: minuteOnes
                        currentValue: String(systemClock?.date?.getMinutes()).padStart(2, '0').charAt(1)
                    }
                }
            }
            
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacingXS
                text: systemClock?.date?.toLocaleDateString(Qt.locale(), "MMM dd")
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeAllCursor
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }
}
