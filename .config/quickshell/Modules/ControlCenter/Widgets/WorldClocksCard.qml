import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property int maxClocks: 4

    readonly property real _pad: Theme.spacingM
    readonly property var clocks: (SettingsData.worldClocks || []).slice(0, maxClocks)

    // Qt's JS runtime may ignore Intl timeZone; use `TZ=... date` for correctness.
    property var _timeByIndex: ({})    // idx -> "1:07 PM"
    property var _offsetByIndex: ({})  // idx -> "+2" / "-5"

    function timeForIndex(i) { return _timeByIndex[i] !== undefined ? _timeByIndex[i] : "" }
    function offsetForIndex(i) { return _offsetByIndex[i] !== undefined ? _offsetByIndex[i] : "" }

    function _offsetFromZ(z) {
        // Expect "+HHMM" or "-HHMM"
        const m = ("" + z).trim().match(/^([+-])(\d{2})(\d{2})$/)
        if (!m) return ""
        const sign = m[1]
        const hh = parseInt(m[2], 10)
        const mm = parseInt(m[3], 10)
        const hours = hh + (mm >= 30 ? 1 : 0)
        return (sign === "+" ? "+" : "-") + hours
    }

    function refreshTimes() {
        if (!root.visible) return
        if (tzProcess.running) return

        const clocks = root.clocks || []
        if (clocks.length === 0) {
            root._timeByIndex = ({})
            root._offsetByIndex = ({})
            return
        }

        let script = ""
        for (let i = 0; i < clocks.length; i++) {
            const tz = (clocks[i].timeZone || "").toString().replace(/"/g, '\\"')
            // Print 3 lines per clock: marker, time, offset
            script += "echo \"===IDX " + i + "\";"
            script += "TZ=\"" + tz + "\" date \"+%I:%M %p\";"
            script += "TZ=\"" + tz + "\" date \"+%z\";"
        }
        tzProcess.command = ["sh", "-c", script]
        tzProcess.running = true
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.visible
        onTriggered: root.refreshTimes()
    }

    onVisibleChanged: {
        if (visible) refreshTimes()
    }
    onClocksChanged: refreshTimes()

    radius: 12
    antialiasing: true
    color: {
        const alpha = Theme.getContentBackgroundAlpha() * SettingsData.controlCenterWidgetBackgroundOpacity
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
    }
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
    border.width: 1

    implicitHeight: headerRow.implicitHeight + listColumn.implicitHeight + _pad * 2 + Theme.spacingM + 10

    Column {
        anchors.fill: parent
        anchors.margins: root._pad
        spacing: 10

        Row {
            id: headerRow
            width: parent.width
            spacing: 8

            EHIcon {
                name: "schedule"
                size: 16
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "World Clocks"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Column {
            id: listColumn
            width: parent.width
            spacing: 6

            Repeater {
                model: root.clocks

                delegate: RowLayout {
                    id: clockRow
                    width: listColumn.width
                    spacing: 10

                    readonly property int _cityW: Math.round(listColumn.width * 0.36)
                    readonly property int _timeW: Math.round(listColumn.width * 0.30)

                    StyledText {
                        Layout.preferredWidth: clockRow._cityW
                        Layout.maximumWidth: clockRow._cityW
                        Layout.minimumWidth: clockRow._cityW
                        Layout.preferredHeight: Theme.fontSizeSmall + 8
                        Layout.maximumHeight: Theme.fontSizeSmall + 8
                        Layout.alignment: Qt.AlignVCenter
                        verticalAlignment: Text.AlignBottom
                        maximumLineCount: 1
                        text: (modelData.label || modelData.timeZone || "").toString()
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillWidth: true; Layout.minimumWidth: 4 }

                    ColumnLayout {
                        Layout.preferredWidth: clockRow._timeW
                        Layout.maximumWidth: clockRow._timeW
                        Layout.minimumWidth: clockRow._timeW
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        StyledText {
                            Layout.preferredWidth: clockRow._timeW
                            Layout.maximumWidth: clockRow._timeW
                            Layout.minimumWidth: clockRow._timeW
                            Layout.alignment: Qt.AlignHCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: root.timeForIndex(index)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Item {
                            Layout.preferredWidth: clockRow._timeW
                            Layout.maximumWidth: clockRow._timeW
                            Layout.minimumWidth: clockRow._timeW
                            Layout.preferredHeight: offsetLabel.implicitHeight
                            Layout.alignment: Qt.AlignHCenter

                            StyledText {
                                id: offsetLabel
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.horizontalCenterOffset: -1
                                text: root.offsetForIndex(index)
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.65)
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }

            StyledText {
                visible: root.clocks.length === 0
                text: "No clocks configured"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheelEvent => { wheelEvent.accepted = true }
    }

    Process {
        id: tzProcess
        running: false
        command: []

        property int _curIdx: -1
        property int _nextField: 0 // 0=time 1=offset
        property var _t: ({})
        property var _o: ({})

        onStarted: {
            _curIdx = -1
            _nextField = 0
            _t = ({})
            _o = ({})
        }

        onExited: (exitCode, exitStatus) => {
            // Even if the shell fails, publish whatever we parsed (avoids stale data)
            root._timeByIndex = _t
            root._offsetByIndex = _o
            tzProcess.running = false
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: lineRaw => {
                const line = ("" + lineRaw).replace(/\s+$/, "")
                const m = line.match(/^===IDX\s+(\d+)\s*$/)
                if (m && m[1] !== undefined) {
                    tzProcess._curIdx = parseInt(m[1], 10)
                    tzProcess._nextField = 0
                    return
                }
                if (tzProcess._curIdx < 0) return

                if (tzProcess._nextField === 0) {
                    tzProcess._t[tzProcess._curIdx] = line.trim()
                    tzProcess._nextField = 1
                } else {
                    tzProcess._o[tzProcess._curIdx] = root._offsetFromZ(line)
                    tzProcess._nextField = 0
                }
            }
        }
    }
}

