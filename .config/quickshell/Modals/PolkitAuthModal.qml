import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DarkModal {
    id: root

    property string passwordInput: ""
    property var currentFlow: PolkitService.agent?.flow
    property bool isLoading: false
    property bool awaitingFprintForPassword: false

    function _focusPasswordField() {
        if (passwordField)
            passwordField.forceActiveFocus()
    }

    function show() {
        passwordInput = ""
        isLoading = false
        awaitingFprintForPassword = false
        open()
        Qt.callLater(_focusPasswordField)
    }

    function hide() {
        close()
    }

    function _commitSubmit() {
        isLoading = true
        awaitingFprintForPassword = false
        currentFlow.submit(passwordInput)
        passwordInput = ""
    }

    function submitAuth() {
        if (!currentFlow || isLoading)
            return
        if (!currentFlow.isResponseRequired) {
            awaitingFprintForPassword = true
            return
        }
        _commitSubmit()
    }

    function cancelAuth() {
        if (isLoading)
            return
        awaitingFprintForPassword = false
        if (currentFlow) {
            currentFlow.cancelAuthenticationRequest()
            return
        }
        hide()
    }

    shouldBeVisible: false
    width: 460
    height: 240
    onShouldBeVisibleChanged: {
        if (!shouldBeVisible) {
            passwordInput = ""
            isLoading = false
            awaitingFprintForPassword = false
        }
    }
    onOpened: Qt.callLater(_focusPasswordField)
    onBackgroundClicked: cancelAuth()

    Connections {
        target: PolkitService.agent
        enabled: PolkitService.polkitAvailable

        function onAuthenticationRequestStarted() {
            show()
        }

        function onIsActiveChanged() {
            if (!(PolkitService.agent?.isActive ?? false))
                hide()
        }
    }

    Connections {
        target: currentFlow
        enabled: currentFlow !== null

        function onIsResponseRequiredChanged() {
            if (!currentFlow.isResponseRequired)
                return
            if (awaitingFprintForPassword && passwordInput !== "") {
                _commitSubmit()
                return
            }
            awaitingFprintForPassword = false
            isLoading = false
            passwordInput = ""
            Qt.callLater(_focusPasswordField)
        }

        function onAuthenticationSucceeded() {
            hide()
        }

        function onAuthenticationFailed() {
            isLoading = false
            Qt.callLater(_focusPasswordField)
        }

        function onAuthenticationRequestCancelled() {
            hide()
        }
    }

    content: Component {
        FocusScope {
            id: contentFocusScope
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: event => {
                root.cancelAuth()
                event.accepted = true
            }

            Rectangle {
                id: shell
                anchors.fill: parent
                radius: Theme.cornerRadius + 6
                clip: true
                color: Qt.rgba(
                    Theme.surfaceContainer.r,
                    Theme.surfaceContainer.g,
                    Theme.surfaceContainer.b,
                    0.92
                )
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Qt.rgba(Theme.surfaceTint.r, Theme.surfaceTint.g, Theme.surfaceTint.b, 1.0)
                    opacity: 0.035
                    visible: true
                    enabled: false
                    z: -1
                }

                Column {
                    id: mainColumn
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingM

                    EHIcon {
                        Layout.alignment: Qt.AlignTop
                        name: "lock"
                        size: Math.round(22 * (Appearance.combinedScale || 1))
                        color: Theme.primary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXS

                        StyledText {
                            Layout.fillWidth: true
                            text: I18n.tr("Authentication Required")
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: currentFlow?.message ?? ""
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceTextMedium
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            visible: text !== ""
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: currentFlow?.supplementaryMessage ?? ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: (currentFlow?.supplementaryIsError ?? false) ? Theme.error : Theme.surfaceTextMedium
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            opacity: (currentFlow?.supplementaryIsError ?? false) ? 1 : 0.8
                            visible: text !== ""
                        }
                    }

                    EHActionButton {
                        Layout.alignment: Qt.AlignTop
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        enabled: !root.isLoading
                        opacity: enabled ? 1 : 0.5
                        onClicked: root.cancelAuth()
                    }
                }

                Item { width: 1; height: 2 }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: currentFlow?.inputPrompt ?? ""
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        width: parent.width
                        visible: text !== ""
                    }

                    EHTextField {
                        id: passwordField
                        width: parent.width
                        backgroundColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55)
                        normalBorderColor: Theme.outlineStrong
                        focusedBorderColor: Theme.primary
                        borderWidth: 1
                        focusedBorderWidth: 2
                        placeholderText: ""
                        showClearButton: true
                        opacity: root.isLoading ? 0.5 : 1
                        text: root.passwordInput
                        echoMode: (currentFlow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
                        enabled: !root.isLoading
                        onTextEdited: root.passwordInput = text
                        onAccepted: root.submitAuth()
                    }

                    StyledText {
                        text: I18n.tr("Authentication failed, please try again")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                        width: parent.width
                        visible: currentFlow?.failed ?? false
                    }

                    Item {
                        width: parent.width
                        height: 36

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingM

                            Rectangle {
                                width: Math.max(70, cancelText.contentWidth + Theme.spacingM * 2)
                                height: 36
                                radius: height / 2
                                color: cancelArea.containsMouse
                                    ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
                                    : "transparent"
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.22)
                                border.width: 1
                                enabled: !root.isLoading
                                opacity: enabled ? 1 : 0.5

                                StyledText {
                                    id: cancelText
                                    anchors.centerIn: parent
                                    text: I18n.tr("Cancel")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: cancelArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: parent.enabled
                                    onClicked: root.cancelAuth()
                                }
                            }

                            Rectangle {
                                width: Math.max(110, authText.contentWidth + Theme.spacingM * 2)
                                height: 36
                                radius: height / 2
                                color: authArea.containsMouse
                                    ? Qt.darker(Theme.primary, 1.08)
                                    : Theme.primary
                                enabled: !root.isLoading
                                opacity: enabled ? 1 : 0.5

                                StyledText {
                                    id: authText
                                    anchors.centerIn: parent
                                    text: root.awaitingFprintForPassword ? I18n.tr("Waiting…") : I18n.tr("Authenticate")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.background
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: authArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: parent.enabled
                                    onClicked: root.submitAuth()
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
}

