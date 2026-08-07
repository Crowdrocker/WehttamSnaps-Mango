import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Services

Column {
    id: root

    property var items: []
    property var allWidgets: []
    property string title: ""
    property string titleIcon: "widgets"
    property string sectionId: ""

    signal itemEnabledChanged(string sectionId, string itemId, bool enabled)
    signal itemOrderChanged(var newOrder)
    signal addWidget(string sectionId)
    signal removeWidget(string sectionId, int widgetIndex)
    signal spacerSizeChanged(string sectionId, int widgetIndex, int newSize)
    signal compactModeChanged(string widgetId, var value)
    signal gpuSelectionChanged(string sectionId, int widgetIndex, int selectedIndex)
    signal controlCenterSettingChanged(string sectionId, int widgetIndex, string settingName, bool value)

    width: parent.width
    height: implicitHeight
    spacing: Theme.spacingM

    RowLayout {
        width: parent.width
        spacing: Theme.spacingM

        EHIcon {
            name: root.titleIcon
            size: Theme.iconSize
            color: Theme.primary
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: root.title
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.fillWidth: true
        }
    }

    Column {
        id: itemsList

        width: parent.width
        spacing: Theme.spacingM

        Repeater {
            model: root.items

            delegate: Item {
                id: delegateItem

                property bool held: dragArea.pressed
                property real originalY: y

                width: itemsList.width
                height: 64
                z: held ? 2 : 1

                StyledRect {
                    id: itemBackground

                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, Theme.popupTransparency)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 1

                    RowLayout {
                        id: headerRow
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingL * 2
                        height: parent.height
                        spacing: Theme.spacingM

                        Item {
                            Layout.preferredWidth: Theme.iconSize
                            Layout.preferredHeight: Theme.iconSize
                            Layout.alignment: Qt.AlignVCenter

                            EHIcon {
                                name: "drag_indicator"
                                size: Theme.iconSize - 4
                                color: Theme.outline
                                anchors.centerIn: parent
                                opacity: dragArea.containsMouse ? 1.0 : 0.6
                            }

                            MouseArea {
                                id: dragArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.SizeVerCursor
                                drag.target: held ? delegateItem : undefined
                                drag.axis: Drag.YAxis
                                drag.minimumY: -delegateItem.height
                                drag.maximumY: itemsList.height
                                preventStealing: true
                                onPressed: {
                                    delegateItem.z = 2
                                    delegateItem.originalY = delegateItem.y
                                }
                                onReleased: {
                                    delegateItem.z = 1
                                    if (drag.active) {
                                        var newIndex = Math.round(
                                                    delegateItem.y / (delegateItem.height
                                                                      + itemsList.spacing))
                                        newIndex = Math.max(
                                                    0, Math.min(newIndex,
                                                                root.items.length - 1))
                                        if (newIndex !== index) {
                                            var newItems = root.items.slice()
                                            var draggedItem = newItems.splice(index,
                                                                              1)[0]
                                            newItems.splice(newIndex, 0, draggedItem)
                                            root.itemOrderChanged(newItems.map(item => {
                                                                                   return ({
                                                                                               "id": item.id,
                                                                                               "enabled": item.enabled,
                                                                                               "size": item.size
                                                                                           })
                                                                               }))
                                        }
                                    }
                                    delegateItem.x = 0
                                    delegateItem.y = delegateItem.originalY
                                }
                            }
                        }

                        EHIcon {
                            name: modelData.icon
                            size: Theme.iconSize
                            color: modelData.enabled ? Theme.primary : Theme.outline
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: Theme.iconSize
                            Layout.preferredHeight: Theme.iconSize
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                id: titleText
                                text: modelData.text
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: modelData.enabled ? Theme.surfaceText : Theme.outline
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            StyledText {
                                text: modelData.description
                                font.pixelSize: Theme.fontSizeSmall
                                color: modelData.enabled ? Theme.surfaceVariantText : Qt.rgba(
                                                               Theme.outline.r,
                                                               Theme.outline.g,
                                                               Theme.outline.b, 0.6)
                                elide: Text.ElideRight
                                width: parent.width
                                wrapMode: Text.WordWrap
                                maximumLineCount: 1
                            }
                        }

                        Item {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignVCenter
                            visible: modelData.id === "gpuTemp"

                            EHDropdown {
                                id: gpuDropdown
                                anchors.fill: parent
                                currentValue: {
                                    var selectedIndex = modelData.selectedGpuIndex
                                            !== undefined ? modelData.selectedGpuIndex : 0
                                    if (DgopService.availableGpus
                                            && DgopService.availableGpus.length > selectedIndex
                                            && selectedIndex >= 0) {
                                        var gpu = DgopService.availableGpus[selectedIndex]
                                        return gpu.driver.toUpperCase()
                                    }
                                    return DgopService.availableGpus
                                            && DgopService.availableGpus.length
                                            > 0 ? DgopService.availableGpus[0].driver.toUpperCase(
                                                      ) : ""
                                }
                                options: {
                                    var gpuOptions = []
                                    if (DgopService.availableGpus
                                            && DgopService.availableGpus.length > 0) {
                                        for (var i = 0; i < DgopService.availableGpus.length; i++) {
                                            var gpu = DgopService.availableGpus[i]
                                            gpuOptions.push(
                                                        gpu.driver.toUpperCase(
                                                            ))
                                        }
                                    }
                                    return gpuOptions
                                }
                                onValueChanged: value => {
                                                    var gpuIndex = options.indexOf(
                                                        value)
                                                    if (gpuIndex >= 0) {
                                                        root.gpuSelectionChanged(
                                                            root.sectionId,
                                                            index, gpuIndex)
                                                    }
                                                }
                            }
                        }

                        Item {
                            Layout.preferredWidth: Theme.iconSize
                            Layout.preferredHeight: Theme.iconSize
                            Layout.alignment: Qt.AlignVCenter
                            visible: (modelData.warning !== undefined
                                      && modelData.warning !== "")
                                     && (modelData.id === "cpuUsage"
                                         || modelData.id === "memUsage"
                                         || modelData.id === "cpuTemp"
                                         || modelData.id === "gpuTemp")

                            EHIcon {
                                name: "warning"
                                size: 20
                                color: Theme.error
                                anchors.centerIn: parent
                                opacity: warningArea.containsMouse ? 1.0 : 0.8
                            }

                            MouseArea {
                                id: warningArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                            }

                            Rectangle {
                                id: warningTooltip

                                property string warningText: (modelData.warning !== undefined
                                                              && modelData.warning
                                                              !== "") ? modelData.warning : ""

                                width: Math.min(
                                           250,
                                           warningTooltipText.implicitWidth) + Theme.spacingM * 2
                                height: warningTooltipText.implicitHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainer
                                border.color: Theme.outline
                                border.width: 1
                                visible: warningArea.containsMouse
                                         && warningText !== ""
                                opacity: visible ? 1 : 0
                                x: -width - Theme.spacingS
                                y: (parent.height - height) / 2
                                z: 100

                                StyledText {
                                    id: warningTooltipText
                                    anchors.centerIn: parent
                                    anchors.margins: Theme.spacingS
                                    text: warningTooltip.warningText
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    width: Math.min(250, implicitWidth)
                                    wrapMode: Text.WordWrap
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }
                        }

                        RowLayout {
                            spacing: Theme.spacingXS
                            Layout.alignment: Qt.AlignVCenter
                            visible: modelData.id === "clock"
                                     || modelData.id === "music"
                                     || modelData.id === "focusedWindow"
                                     || modelData.id === "runningApps"

                            EHActionButton {
                                id: smallSizeButton
                                buttonSize: 28
                                visible: modelData.id === "music"
                                iconName: "photo_size_select_small"
                                iconSize: 16
                                iconColor: SettingsData.mediaSize
                                           === 0 ? Theme.primary : Theme.outline
                                onClicked: {
                                    root.compactModeChanged("music", 0)
                                }
                            }

                            EHActionButton {
                                id: mediumSizeButton
                                buttonSize: 28
                                visible: modelData.id === "music"
                                iconName: "photo_size_select_actual"
                                iconSize: 16
                                iconColor: SettingsData.mediaSize
                                           === 1 ? Theme.primary : Theme.outline
                                onClicked: {
                                    root.compactModeChanged("music", 1)
                                }
                            }

                            EHActionButton {
                                id: largeSizeButton
                                buttonSize: 28
                                visible: modelData.id === "music"
                                iconName: "photo_size_select_large"
                                iconSize: 16
                                iconColor: SettingsData.mediaSize
                                           === 2 ? Theme.primary : Theme.outline
                                onClicked: {
                                    root.compactModeChanged("music", 2)
                                }
                            }

                            EHActionButton {
                                id: compactModeButton
                                buttonSize: 28
                                visible: modelData.id === "clock"
                                         || modelData.id === "focusedWindow"
                                         || modelData.id === "runningApps"
                                iconName: {
                                    if (modelData.id === "clock")
                                        return SettingsData.clockCompactMode ? "zoom_out" : "zoom_in"
                                    if (modelData.id === "focusedWindow")
                                        return SettingsData.focusedWindowCompactMode ? "zoom_out" : "zoom_in"
                                    if (modelData.id === "runningApps")
                                        return SettingsData.runningAppsCompactMode ? "zoom_out" : "zoom_in"
                                    return "zoom_in"
                                }
                                iconSize: 16
                                iconColor: {
                                    if (modelData.id === "clock")
                                        return SettingsData.clockCompactMode ? Theme.primary : Theme.outline
                                    if (modelData.id === "focusedWindow")
                                        return SettingsData.focusedWindowCompactMode ? Theme.primary : Theme.outline
                                    if (modelData.id === "runningApps")
                                        return SettingsData.runningAppsCompactMode ? Theme.primary : Theme.outline
                                    return Theme.outline
                                }
                                onClicked: {
                                    if (modelData.id === "clock") {
                                        root.compactModeChanged(
                                                    "clock",
                                                    !SettingsData.clockCompactMode)
                                    } else if (modelData.id === "focusedWindow") {
                                        root.compactModeChanged(
                                                    "focusedWindow",
                                                    !SettingsData.focusedWindowCompactMode)
                                    } else if (modelData.id === "runningApps") {
                                        root.compactModeChanged(
                                                    "runningApps",
                                                    !SettingsData.runningAppsCompactMode)
                                    }
                                }
                            }

                            Rectangle {
                                id: compactModeTooltip
                                width: tooltipText.contentWidth + Theme.spacingM * 2
                                height: tooltipText.contentHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainer
                                border.color: Theme.outline
                                border.width: 1
                                visible: false
                                opacity: visible ? 1 : 0
                                x: -width - Theme.spacingS
                                y: (parent.height - height) / 2
                                z: 100

                                StyledText {
                                    id: tooltipText
                                    anchors.centerIn: parent
                                    text: "Compact Mode"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }
                        }

                        EHActionButton {
                            id: moreVertBtn
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: Theme.iconSize
                            Layout.preferredHeight: Theme.iconSize
                            visible: modelData.id === "controlCenterButton"
                            iconName: "more_vert"
                            onClicked: {
                                controlCenterContextMenu.widgetData = modelData
                                controlCenterContextMenu.sectionId = root.sectionId
                                controlCenterContextMenu.widgetIndex = index
                                var btnCenter = moreVertBtn.mapToItem(root, moreVertBtn.width / 2, moreVertBtn.height / 2)
                                controlCenterContextMenu.x = Math.max(0, btnCenter.x - controlCenterContextMenu.width / 2)
                                controlCenterContextMenu.y = btnCenter.y + moreVertBtn.height / 2 + Theme.spacingXS
                                controlCenterContextMenu.open()
                            }
                        }

                        Item {
                            Layout.preferredWidth: Theme.iconSize
                            Layout.preferredHeight: Theme.iconSize
                            Layout.alignment: Qt.AlignVCenter
                            visible: modelData.id !== "spacer"

                            EHToggle {
                                anchors.centerIn: parent
                                checked: modelData.enabled
                                onToggled: isChecked => {
                                    root.itemEnabledChanged(root.sectionId,
                                                            modelData.id,
                                                            isChecked)
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.spacingXS
                            visible: modelData.id === "spacer"

                            EHActionButton {
                                buttonSize: 24
                                iconName: "remove"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var currentSize = modelData.size || 20
                                    var newSize = Math.max(5, currentSize - 5)
                                    root.spacerSizeChanged(root.sectionId,
                                                           index,
                                                           newSize)
                                }
                            }

                            StyledText {
                                text: (modelData.size || 20).toString()
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                Layout.alignment: Qt.AlignVCenter
                            }

                            EHActionButton {
                                buttonSize: 24
                                iconName: "add"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var currentSize = modelData.size || 20
                                    var newSize = Math.min(5000,
                                                           currentSize + 5)
                                    root.spacerSizeChanged(root.sectionId,
                                                           index,
                                                           newSize)
                                }
                            }
                        }

                        EHActionButton {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: Theme.iconSize
                            Layout.preferredHeight: Theme.iconSize
                            iconName: "close"
                            iconColor: Theme.error
                            onClicked: {
                                root.removeWidget(root.sectionId, index)
                            }
                        }
                    }

                    Behavior on y {
                        enabled: !dragArea.held && !dragArea.drag.active

                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }
        }
    }

    StyledRect {
        width: Math.min(400, parent.width)
        height: 56
        radius: Theme.cornerRadius
        color: addButtonArea.containsMouse ? 
            Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : 
            Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
        border.color: addButtonArea.containsMouse ? 
            Theme.primary : 
            Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
        border.width: 2

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingM

            Rectangle {
                width: 40
                height: 40
                radius: Theme.cornerRadius
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter

                EHIcon {
                    anchors.centerIn: parent
                    name: "add"
                    size: Theme.iconSize
                    color: Theme.onPrimary
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                StyledText {
                    text: "Add Widget"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    text: "Browse and add widgets"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }

        MouseArea {
            id: addButtonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.addWidget(root.sectionId)
            }
        }
    }

    Popup {
        id: controlCenterContextMenu

        property var widgetData: null
        property string sectionId: ""
        property int widgetIndex: -1

        width: 200
        height: menuColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: {
        }

        onClosed: {
        }

        background: Rectangle {
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 1)
            radius: Theme.cornerRadiusSmall
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 1
        }

        contentItem: Item {

            Column {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Rectangle {
                    id: networkRow
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: networkRowArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                    property bool toggled: SettingsData.controlCenterShowNetworkIcon

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        EHIcon {
                            name: "lan"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Network Icon"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: networkRow.toggled ? Theme.primary : Theme.surfaceVariantAlpha
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                            border.width: 1

                            Rectangle {
                                width: parent.height - 4
                                height: parent.height - 4
                                radius: width / 2
                                color: networkRow.toggled ? Theme.surface : Theme.outline
                                border.color: Theme.outline
                                border.width: networkRow.toggled ? 1 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: networkRow.toggled ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }
                        }
                    }

                    MouseArea {
                        id: networkRowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, "showNetworkIcon", !SettingsData.controlCenterShowNetworkIcon)
                        }
                    }
                }

                Rectangle {
                    id: bluetoothRow
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: bluetoothRowArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                    property bool toggled: SettingsData.controlCenterShowBluetoothIcon

                    RowLayout {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        EHIcon {
                            name: "bluetooth"
                            size: 16
                            color: Theme.surfaceText
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: "Bluetooth Icon"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    Item {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: bluetoothRow.toggled ? Theme.primary : Theme.surfaceVariantAlpha
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                            border.width: 1

                            Rectangle {
                                width: parent.height - 4
                                height: parent.height - 4
                                radius: width / 2
                                color: bluetoothRow.toggled ? Theme.surface : Theme.outline
                                border.color: Theme.outline
                                border.width: bluetoothRow.toggled ? 1 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: bluetoothRow.toggled ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }
                        }
                    }

                    MouseArea {
                        id: bluetoothRowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, "showBluetoothIcon", !SettingsData.controlCenterShowBluetoothIcon)
                        }
                    }
                }

                Rectangle {
                    id: audioRow
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: audioRowArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                    property bool toggled: SettingsData.controlCenterShowAudioIcon

                    RowLayout {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        EHIcon {
                            name: "volume_up"
                            size: 16
                            color: Theme.surfaceText
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: "Audio Icon"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    Item {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: audioRow.toggled ? Theme.primary : Theme.surfaceVariantAlpha
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                            border.width: 1

                            Rectangle {
                                width: parent.height - 4
                                height: parent.height - 4
                                radius: width / 2
                                color: audioRow.toggled ? Theme.surface : Theme.outline
                                border.color: Theme.outline
                                border.width: audioRow.toggled ? 1 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: audioRow.toggled ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }
                        }
                    }

                    MouseArea {
                        id: audioRowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, "showAudioIcon", !SettingsData.controlCenterShowAudioIcon)
                        }
                    }
                }

                Rectangle {
                    id: micRow
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: micRowArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                    property bool toggled: SettingsData.controlCenterShowMicIcon

                    RowLayout {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        EHIcon {
                            name: "mic"
                            size: 16
                            color: Theme.surfaceText
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: "Microphone Icon"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    Item {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: micRow.toggled ? Theme.primary : Theme.surfaceVariantAlpha
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                            border.width: 1

                            Rectangle {
                                width: parent.height - 4
                                height: parent.height - 4
                                radius: width / 2
                                color: micRow.toggled ? Theme.surface : Theme.outline
                                border.color: Theme.outline
                                border.width: micRow.toggled ? 1 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: micRow.toggled ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }
                        }
                    }

                    MouseArea {
                        id: micRowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, "showMicIcon", !SettingsData.controlCenterShowMicIcon)
                        }
                    }
                }
            }

        }
    }
}
