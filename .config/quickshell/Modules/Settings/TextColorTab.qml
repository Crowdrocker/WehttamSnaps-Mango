import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: textColorTab

    property var parentModal: null

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            StyledRect {
                width: parent.width
                height: textColorAdjustmentSection.childrenRect.height + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g,
                               Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: textColorAdjustmentSection

                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    y: Theme.spacingM
                    spacing: Theme.spacingM

                    // Header with toggle
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS
                        topPadding: Theme.spacingXS
                        bottomPadding: Theme.spacingXS

                        EHToggle {
                            id: extractedOverrideToggle
                            checked: SettingsData.extractedColorTextOverrideEnabled
                            onToggled: SettingsData.setExtractedColorTextOverrideEnabled(checked)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - extractedOverrideToggle.width - Theme.spacingS
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Extracted Color Text Override"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: "Override the text color for extracted colors using RGB values"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    Column {
                        id: textColorAdjustmentContent
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Red: " + SettingsData.extractedColorTextR
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                font.weight: Font.Medium
                            }

                            EHSlider {
                                width: parent.width
                                height: 32
                                value: SettingsData.extractedColorTextR
                                minimum: 0
                                maximum: 255
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                enabled: SettingsData.extractedColorTextOverrideEnabled
                                onSliderValueChanged: newValue => {
                                    SettingsData.extractedColorTextR = newValue
                                }
                                onSliderDragFinished: finalValue => {
                                    SettingsData.setExtractedColorTextR(finalValue)
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Green: " + SettingsData.extractedColorTextG
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                font.weight: Font.Medium
                            }

                            EHSlider {
                                width: parent.width
                                height: 32
                                value: SettingsData.extractedColorTextG
                                minimum: 0
                                maximum: 255
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                enabled: SettingsData.extractedColorTextOverrideEnabled
                                onSliderValueChanged: newValue => {
                                    SettingsData.extractedColorTextG = newValue
                                }
                                onSliderDragFinished: finalValue => {
                                    SettingsData.setExtractedColorTextG(finalValue)
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Blue: " + SettingsData.extractedColorTextB
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                font.weight: Font.Medium
                            }

                            EHSlider {
                                width: parent.width
                                height: 32
                                value: SettingsData.extractedColorTextB
                                minimum: 0
                                maximum: 255
                                unit: ""
                                showValue: true
                                wheelEnabled: false
                                enabled: SettingsData.extractedColorTextOverrideEnabled
                                onSliderValueChanged: newValue => {
                                    SettingsData.extractedColorTextB = newValue
                                }
                                onSliderDragFinished: finalValue => {
                                    SettingsData.setExtractedColorTextB(finalValue)
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        topPadding: Theme.spacingS

                        StyledRect {
                            width: (parent.width - Theme.spacingM) / 2
                            height: 40
                            radius: Theme.cornerRadius
                            color: saveButtonMouseArea.containsMouse ? Theme.primary : Theme.primaryContainer

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                EHIcon {
                                    name: "save"
                                    size: 18
                                    color: Theme.primaryText || Theme.onPrimary || "#ffffff"
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "Save"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.primaryText || Theme.onPrimary || "#ffffff"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: saveButtonMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (SettingsData.currentColorTheme) {
                                        SettingsData.saveTextColorPreset(SettingsData.currentColorTheme)
                                    } else {
                                        SettingsData.saveTextColorPreset("")
                                    }
                                    if (typeof ToastService !== 'undefined') {
                                        ToastService.showInfo("RGB text color saved")
                                    }
                                }
                            }
                        }

                        StyledRect {
                            width: (parent.width - Theme.spacingM) / 2
                            height: 40
                            radius: Theme.cornerRadius
                            color: loadButtonMouseArea.containsMouse ? Theme.secondary : (typeof Theme !== 'undefined' && Theme.secondaryContainer ? Theme.secondaryContainer : Theme.surfaceVariant)

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                EHIcon {
                                    name: "folder_open"
                                    size: 18
                                    color: ColorPaletteService.getTextColorForBackground(loadButtonMouseArea.containsMouse ? Theme.secondary : (typeof Theme !== 'undefined' && Theme.secondaryContainer ? Theme.secondaryContainer : Theme.surfaceVariant))
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "Load"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: ColorPaletteService.getTextColorForBackground(loadButtonMouseArea.containsMouse ? Theme.secondary : (typeof Theme !== 'undefined' && Theme.secondaryContainer ? Theme.secondaryContainer : Theme.surfaceVariant))
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: loadButtonMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (SettingsData.currentColorTheme) {
                                        const loaded = SettingsData.loadTextColorFromTheme(SettingsData.currentColorTheme)
                                        if (loaded) {
                                            if (typeof ToastService !== 'undefined') {
                                                ToastService.showInfo("RGB text color loaded from theme")
                                            }
                                        } else {
                                            if (typeof ToastService !== 'undefined') {
                                                ToastService.showInfo("No saved RGB values for this theme")
                                            }
                                        }
                                    } else {
                                        if (typeof ToastService !== 'undefined') {
                                            ToastService.showInfo("No theme selected")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: SettingsData.extractedColorTextOverrideEnabled
                        opacity: visible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }

                        StyledText {
                            text: "Preview"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }

                        Rectangle {
                            width: parent.width
                            height: 60
                            radius: Theme.cornerRadius
                            color: ColorPaletteService.extractedColors.length > 0 && ColorPaletteService.extractedColors[0] ? ColorPaletteService.extractedColors[0] : "#000000"
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                            border.width: 1

                            StyledText {
                                id: previewText
                                anchors.centerIn: parent
                                text: "Sample Text"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                property string previewColor: ColorPaletteService.extractedColors.length > 0 && ColorPaletteService.extractedColors[0] ? ColorPaletteService.extractedColors[0] : "#000000"
                                color: ColorPaletteService.getTextColorForBackground(previewColor)

                                Connections {
                                    target: ColorPaletteService
                                    function onTextColorAdjustmentChanged() {
                                        previewText.color = ColorPaletteService.getTextColorForBackground(previewText.previewColor)
                                    }
                                }

                                Connections {
                                    target: SettingsData
                                    function onExtractedColorTextRChanged() {
                                        previewText.color = ColorPaletteService.getTextColorForBackground(previewText.previewColor)
                                    }
                                    function onExtractedColorTextGChanged() {
                                        previewText.color = ColorPaletteService.getTextColorForBackground(previewText.previewColor)
                                    }
                                    function onExtractedColorTextBChanged() {
                                        previewText.color = ColorPaletteService.getTextColorForBackground(previewText.previewColor)
                                    }
                                    function onExtractedColorTextOverrideEnabledChanged() {
                                        previewText.color = ColorPaletteService.getTextColorForBackground(previewText.previewColor)
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
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
