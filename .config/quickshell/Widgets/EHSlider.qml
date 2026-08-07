import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Common
import qs.Widgets

Item {
    id: slider

    property real value: 50
    property real minimum: 0
    property real maximum: 100
    property string leftIcon: ""
    property string rightIcon: ""
    property bool enabled: true
    property string unit: "%"
    property bool showValue: true
    property bool isDragging: false
    property bool wheelEnabled: true
    property real valueOverride: -1
    readonly property bool containsMouse: sliderMouseArea.containsMouse

    property color thumbOutlineColor: Theme.surfaceContainer
    property color trackColor: enabled ? Theme.outline : Theme.outline
    property real scaleFactor: Appearance.combinedScale
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    signal sliderValueChanged(real newValue)
    signal sliderDragFinished(real finalValue)

    height: 44 * scaleFactor

    function updateValueFromPosition(x) {
        let ratio = Math.max(0, Math.min(1, (x - sliderHandle.width / 2) / (sliderTrack.width - sliderHandle.width)))
        let newValue = Math.round(minimum + ratio * (maximum - minimum))
        if (newValue !== value) {
            value = newValue
            sliderValueChanged(newValue)
        }
    }

        RowLayout {
        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.spacingM * scaleFactor

        EHIcon {
            name: slider.leftIcon
            size: Theme.iconSize * scaleFactor
            color: slider.enabled ? Theme.surfaceText : Theme.surfaceVariantText
            Layout.preferredWidth: Theme.iconSize * scaleFactor
            Layout.preferredHeight: Theme.iconSize * scaleFactor
            Layout.alignment: Qt.AlignVCenter
            visible: slider.leftIcon.length > 0
        }

        StyledRect {
            id: sliderTrack

            height: 8 * scaleFactor
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            radius: 4 * scaleFactor
            color: slider.trackColor
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            border.width: 1
            clip: false

            StyledRect {
                id: sliderFill
                height: parent.height
                radius: Theme.cornerRadius * scaleFactor
                width: {
                    const ratio = (slider.value - slider.minimum) / (slider.maximum - slider.minimum)
                    const travel = sliderTrack.width - sliderHandle.width
                    const center = (travel * ratio) + sliderHandle.width / 2
                    return Math.max(0, Math.min(sliderTrack.width, center))
                }
                color: slider.enabled ? Theme.primary : withAlpha(Theme.onSurface, 0.12)

            }

            StyledRect {
                id: sliderHandle

                property bool active: sliderMouseArea.containsMouse || sliderMouseArea.pressed || slider.isDragging

                width: 18 * scaleFactor
                height: 18 * scaleFactor
                radius: 9 * scaleFactor
                x: {
                    const ratio = (slider.value - slider.minimum) / (slider.maximum - slider.minimum)
                    const travel = sliderTrack.width - width
                    return Math.max(0, Math.min(travel, travel * ratio))
                }
                anchors.verticalCenter: parent.verticalCenter
                color: slider.enabled ? Theme.primary : withAlpha(Theme.onSurface, 0.12)
                border.width: 2
                border.color: slider.thumbOutlineColor


                StyledRect {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: Theme.onPrimary
                    opacity: slider.enabled ? (sliderMouseArea.pressed ? 0.16 : (sliderMouseArea.containsMouse ? 0.08 : 0)) : 0
                    visible: opacity > 0
                }

                StyledRect {
                    anchors.centerIn: parent
                    width: parent.width + 20
                    height: parent.height + 20
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.primary
                    opacity: slider.enabled && slider.focus ? 0.3 : 0
                    visible: opacity > 0
                }

                Rectangle {
                    id: ripple
                    anchors.centerIn: parent
                    width: 0
                    height: 0
                    radius: width / 2
                    color: Theme.onPrimary
                    opacity: 0

                    function start() {
                        opacity = 0.16
                        width = 0
                        height = 0
                        rippleAnimation.start()
                    }

                    SequentialAnimation {
                        id: rippleAnimation
                        NumberAnimation {
                            target: ripple
                            properties: "width,height"
                            to: 28
                            duration: 180
                        }
                        NumberAnimation {
                            target: ripple
                            property: "opacity"
                            to: 0
                            duration: 150
                        }
                    }
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onPressedChanged: {
                        if (pressed && slider.enabled) {
                            ripple.start()
                        }
                    }
                }


                scale: active ? 1.05 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }

            Item {
                id: sliderContainer

                anchors.fill: parent

                MouseArea {
                    id: sliderMouseArea

                    property bool isDragging: false

                    anchors.fill: parent
                    anchors.topMargin: -10
                    anchors.bottomMargin: -10
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: slider.enabled
                    preventStealing: true
                    acceptedButtons: Qt.LeftButton
                    onWheel: wheelEvent => {
                                 if (!slider.wheelEnabled) {
                                     wheelEvent.accepted = false
                                     return
                                 }
                                 let step = Math.max(0.01, (maximum - minimum) / 100)
                                 let newValue = wheelEvent.angleDelta.y > 0 ? Math.min(maximum, value + step) : Math.max(minimum, value - step)
                                 newValue = Math.round(newValue)
                                 if (newValue !== value) {
                                     value = newValue
                                     sliderValueChanged(newValue)
                                 }
                                 wheelEvent.accepted = true
                             }
                    onPressed: mouse => {
                                   if (slider.enabled) {
                                       slider.isDragging = true
                                       sliderMouseArea.isDragging = true
                                       updateValueFromPosition(mouse.x)
                                   }
                               }
                    onReleased: {
                        if (slider.enabled) {
                            slider.isDragging = false
                            sliderMouseArea.isDragging = false
                            slider.sliderDragFinished(slider.value)
                        }
                    }
                    onPositionChanged: mouse => {
                                           if (pressed && slider.isDragging && slider.enabled) {
                                               updateValueFromPosition(mouse.x)
                                           }
                                       }
                    onClicked: mouse => {
                                   if (slider.enabled && !slider.isDragging) {
                                       updateValueFromPosition(mouse.x)
                                   }
                               }
                }
            }

            StyledRect {
                id: valueTooltip

                width: tooltipText.contentWidth + Theme.spacingL * scaleFactor
                height: tooltipText.contentHeight + Theme.spacingS * scaleFactor
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1
                anchors.bottom: parent.top
                anchors.bottomMargin: Theme.spacingM * scaleFactor
                x: Math.max(0, Math.min(parent.width - width, sliderHandle.x + sliderHandle.width/2 - width/2))
                visible: (sliderMouseArea.containsMouse && slider.showValue) || (slider.isDragging && slider.showValue)
                opacity: visible ? 1 : 0
                layer.enabled: true
                layer.smooth: true

                StyledText {
                    id: tooltipText

                    text: (slider.valueOverride >= 0 ? Math.round(slider.valueOverride) : slider.value) + slider.unit
                    font.pixelSize: Theme.fontSizeSmall * scaleFactor
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.centerIn: parent
                    font.hintingPreference: Font.PreferFullHinting
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
        }

        EHIcon {
            name: slider.rightIcon
            size: Theme.iconSize * scaleFactor
            color: slider.enabled ? Theme.surfaceText : Theme.surfaceVariantText
            Layout.preferredWidth: Theme.iconSize * scaleFactor
            Layout.preferredHeight: Theme.iconSize * scaleFactor
            Layout.alignment: Qt.AlignVCenter
            visible: slider.rightIcon.length > 0
        }
    }
}
