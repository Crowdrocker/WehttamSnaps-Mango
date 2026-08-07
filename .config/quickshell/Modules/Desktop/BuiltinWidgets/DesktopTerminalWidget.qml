import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import "../../../Common/ShellUtils.js" as ShellUtils

PanelWindow {
    id: root

    property var modelData: null
    property var screen: modelData || null
    property real widgetWidth:  SettingsData.desktopTerminalWidth
    property real widgetHeight: SettingsData.desktopTerminalHeight
    property bool alwaysVisible: true
    property string position:     SettingsData.desktopTerminalPosition
    property var positioningBox:  null

    property var    outputLines:    []
    property var    commandHistory: []
    property int    historyIndex:   -1
    property string currentDirectory: ""
    property string prompt:         "$ "
    property string currentInput:   ""
    property bool   commandRunning: false

    implicitWidth:  widgetWidth
    implicitHeight: widgetHeight
    visible: alwaysVisible

    WlrLayershell.layer:         WlrLayershell.Background
    WlrLayershell.namespace:     "quickshell:dock:blur"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        left:   position.includes("left")   ? true : false
        right:  position.includes("right")  ? true : false
        top:    position.includes("top")    ? true : false
        bottom: position.includes("bottom") ? true : false
    }

    readonly property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real barExclusiveSize: SettingsData.topBarVisible && !SettingsData.topBarFloat
        ? ((SettingsData.topBarHeight * SettingsData.topbarScale) + SettingsData.topBarSpacing +
           (SettingsData.topBarGothCornersEnabled ? Theme.cornerRadius : 0)) : 0

    margins {
        left: {
            var b = position.includes("left") ? 20 : 0
            return SettingsData.topBarPosition === "left" && !SettingsData.topBarFloat ? b + barExclusiveSize : b
        }
        right: {
            var b = position.includes("right") ? 20 : 0
            return SettingsData.topBarPosition === "right" && !SettingsData.topBarFloat ? b + barExclusiveSize : b
        }
        top: {
            var b = position.includes("top")
                ? (SettingsData.topBarHeight + SettingsData.topBarSpacing + SettingsData.topBarBottomGap + 20) : 0
            return SettingsData.topBarPosition === "top" && !SettingsData.topBarFloat ? b : (position.includes("top") ? 20 : 0)
        }
        bottom: {
            var b = position.includes("bottom")
                ? (SettingsData.dockExclusiveZone + SettingsData.dockBottomGap + 20) : 0
            return SettingsData.topBarPosition === "bottom" && !SettingsData.topBarFloat ? b + barExclusiveSize : b
        }
    }

    Component.onCompleted: {
        outputLines = []
        addOutput("Terminal ready. Type 'help' for commands.")
        updatePrompt()
        updateDirectory()
    }

    Connections {
        target: SettingsData
        function onDesktopTerminalPositionChanged() { position = SettingsData.desktopTerminalPosition }
        function onDesktopTerminalWidthChanged()    { widgetWidth  = SettingsData.desktopTerminalWidth  }
        function onDesktopTerminalHeightChanged()   { widgetHeight = SettingsData.desktopTerminalHeight }
        function onDesktopTerminalEnabledChanged()  {}
    }

    Process {
        id: commandProcess
        running: false
        command: ["sh", "-c", ""]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (exitCode) => {
            commandRunning = false
            var out = stdout.text.trim()
            var err = stderr.text.trim()
            var lines = out.split('\n')
            if (lines.length > 1) {
                var last = lines[lines.length - 1]
                if (last.startsWith('/') || last.startsWith('~')) {
                    currentDirectory = last
                    lines = lines.slice(0, -1)
                    out = lines.join('\n')
                }
            }
            if (exitCode === 0) {
                if (out !== "") addOutput(out)
            } else {
                if (err !== "")      addOutput("Error: " + err, true)
                else if (out !== "") addOutput(out)
                else                 addOutput("Command exited with code: " + exitCode, true)
            }
            updatePrompt()
            inputField.focus = true
        }
    }

    Process {
        id: pwdProcess
        command: ["pwd"]
        running: false
        stdout: StdioCollector {}
        onExited: (exitCode) => {
            if (exitCode === 0) { currentDirectory = stdout.text.trim(); updatePrompt() }
        }
    }

    Process {
        id: cdProcess
        command: ["sh", "-c", ""]
        running: false
        stdout: StdioCollector {}
        onExited: (exitCode) => {
            commandRunning = false
            var out = stdout.text.trim()
            if (out.startsWith("ERROR:")) addOutput(out, true)
            else if (out.startsWith("/") || out.startsWith(Quickshell.env("HOME") || "")) {
                currentDirectory = out
                updatePrompt()
            }
            inputField.focus = true
        }
    }

    function updateDirectory() { pwdProcess.running = true }
    function updatePrompt() {
        const home = Quickshell.env("HOME") || ""
        let dir = currentDirectory
        if (dir.startsWith(home)) dir = "~" + dir.substring(home.length)
        const user = Quickshell.env("USER") || "user"
        prompt = user + "@" + (Quickshell.env("HOSTNAME") || "host") + ":" + dir + "$ "
    }
    function addOutput(text, isError) {
        if (!text) return
        const lines = text.split('\n')
        for (var i = 0; i < lines.length; i++)
            outputLines.push({ text: lines[i], isError: isError || false })
        if (outputLines.length > 1000) outputLines = outputLines.slice(-500)
        outputView.positionViewAtEnd()
    }
    function executeCommand(command) {
        if (!command || command.trim() === "") return
        const cmd = command.trim()
        if (cmd === "clear" || cmd === "cls") { outputLines = []; updatePrompt(); inputField.focus = true; return }
        if (cmd === "help") {
            addOutput("Available commands:")
            addOutput("  help        – show this message")
            addOutput("  clear/cls   – clear the terminal")
            addOutput("  exit        – close terminal (use settings to disable)")
            addOutput("All other commands are executed in your shell.")
            updatePrompt(); inputField.focus = true; return
        }
        addOutput(prompt + cmd)
        commandHistory.push(cmd)
        historyIndex = commandHistory.length
        if (commandHistory.length > 100) commandHistory = commandHistory.slice(-100)
        if (cmd.startsWith("cd ")) {
            const safe = ShellUtils.buildSafeCdCommand(cmd.substring(3).trim())
            if (!safe) { addOutput("Error: Invalid directory path", true); return }
            commandRunning = true
            cdProcess.command = ["sh", "-c", safe]
            cdProcess.running = true
            return
        }
        if (!ShellUtils.isValidCommand(cmd)) { addOutput("Error: Invalid command", true); return }
        commandRunning = true
        const safeCmd = ShellUtils.buildSafeCommand(cmd)
        if (!safeCmd) { addOutput("Error: Failed to build safe command", true); commandRunning = false; return }
        commandProcess.command = ["sh", "-c", safeCmd]
        commandProcess.running = true
    }

    // ── Visual shell ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b,
                       SettingsData.desktopTerminalOpacity)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b,
                               SettingsData.desktopWidgetBorderOpacity)
        border.width: SettingsData.desktopWidgetBorderThickness
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            // Title bar
            Row {
                width: parent.width
                height: 24
                spacing: 6

                Rectangle {
                    width: 3; height: 16; radius: 2
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "TERMINAL"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Output area
            Rectangle {
                width: parent.width
                height: parent.height - 24 - 38 - Theme.spacingS * 2
                color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.75)
                radius: Theme.cornerRadius * 0.5
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1
                clip: true

                Flickable {
                    id: outputFlickable
                    anchors.fill: parent
                    anchors.margins: 8
                    contentWidth: width
                    contentHeight: outputCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: outputCol
                        width: parent.width
                        spacing: 1

                        Repeater {
                            model: outputLines
                            Text {
                                width: outputCol.width
                                text: modelData.text
                                color: modelData.isError ? Theme.error : Theme.surfaceText
                                font.family: SettingsData.monoFontFamily
                                font.pixelSize: Math.max(1, SettingsData.desktopTerminalFontSize || 12)
                                wrapMode: Text.Wrap
                            }
                        }

                        onImplicitHeightChanged: outputFlickable.contentY = Math.max(0, implicitHeight - outputFlickable.height)
                    }
                }
            }

            // Prompt input bar
            Rectangle {
                width: parent.width
                height: 38
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.4)
                radius: Theme.cornerRadius * 0.5
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        id: promptText
                        text: root.prompt
                        color: Theme.primary
                        font.family: SettingsData.monoFontFamily
                        font.pixelSize: SettingsData.desktopTerminalFontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: inputField
                        width: parent.width - promptText.width - parent.spacing - parent.anchors.leftMargin - parent.anchors.rightMargin
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.surfaceText
                        font.family: SettingsData.monoFontFamily
                        font.pixelSize: SettingsData.desktopTerminalFontSize
                        selectByMouse: true
                        focus: true

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (!commandRunning) { executeCommand(text); text = "" }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                if (commandHistory.length > 0) {
                                    if (historyIndex > 0) historyIndex--
                                    text = commandHistory[historyIndex]
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                if (commandHistory.length > 0 && historyIndex < commandHistory.length - 1) {
                                    historyIndex++; text = commandHistory[historyIndex]
                                } else { historyIndex = commandHistory.length; text = "" }
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }
}
