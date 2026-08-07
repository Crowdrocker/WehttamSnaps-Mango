import "../Common/fzf.js" as Fzf
import QtQuick
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

Rectangle {
    id: root
    
    property real scaleFactor: Appearance.combinedScale
    
    FontLoader {
        id: interFontLoader
        source: StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.config/quickshell/assets/fonts/inter/InterVariable.ttf"
    }
    
    readonly property string interFontFamily: interFontLoader.status === FontLoader.Ready ? interFontLoader.name : "Inter"

    property string text: ""
    property string description: ""
    property string currentValue: ""
    property var options: []

    onOptionsChanged: {
        updateMaxOptionTextWidth()
    }

    Component.onCompleted: {
        updateMaxOptionTextWidth()
        forceRecreateTimer.start()
    }
    property var optionIcons: []
    property bool forceRecreate: false
    property bool enableFuzzySearch: false
    property int popupWidthOffset: 0
    property int maxPopupHeight: 400
    property int controlHeight: 48

    signal valueChanged(string value)

    width: parent.width
    height: Math.max(60, dropdown.height + Theme.spacingL * 2)
    radius: Math.max(Theme.cornerRadius, 12)
    color: "transparent"

    readonly property int horizontalPadding: Theme.spacingM
    readonly property int verticalPadding: Theme.spacingS
    readonly property int dropdownHorizontalPadding: Theme.spacingM
    readonly property int dropdownVerticalPadding: Theme.spacingS

    Component.onDestruction: {
        const popup = popupLoader.item
        if (popup && popup.showPopup) {
            popup.close()
        }
    }

    onVisibleChanged: {
        const popup = popupLoader.item
        if (!visible && popup && popup.showPopup) {
            popup.close()
        } else if (visible) {
            forceRecreateTimer.start()
        }
    }

    Timer {
        id: forceRecreateTimer
        interval: 50
        repeat: false
        onTriggered: root.forceRecreate = !root.forceRecreate
    }

    Column {
        anchors.left: parent.left
        anchors.right: dropdown.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: Theme.spacingL
        spacing: Theme.spacingXS

        StyledText {
            text: root.text
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
            visible: root.text.length > 0 && (!root.currentValue || root.currentValue === "")
            width: parent.width
            elide: Text.ElideRight
        }

        StyledText {
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            visible: description.length > 0
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }

    TextMetrics {
        id: textMetrics
        font.pixelSize: Theme.fontSizeMedium
        font.weight: (root.currentValue && root.currentValue !== "") ? Font.Normal : Font.Medium
        text: {
            if (root.currentValue && root.currentValue !== "") {
                return root.currentValue
            }
            return root.text || "Select..."
        }
    }

    property real maxOptionTextWidth: 0

    function updateMaxOptionTextWidth() {
        let maxWidth = textMetrics.width
        for (const option of root.options) {
            maxTextMetrics.text = option
            if (maxTextMetrics.width > maxWidth) {
                maxWidth = maxTextMetrics.width
            }
        }
        root.maxOptionTextWidth = maxWidth
    }

    TextMetrics {
        id: maxTextMetrics
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Normal
    }

    onCurrentValueChanged: {
        Qt.callLater(() => {
            if (!root || !textMetrics) return
            textMetrics.text = root.currentValue && root.currentValue !== "" ? root.currentValue : (root.text || "Select...")
        })
    }

    onTextChanged: {
        if (!root.currentValue || root.currentValue === "") {
            Qt.callLater(() => {
                if (!root || !textMetrics) return
                textMetrics.text = root.text || "Select..."
            })
        }
    }

    Rectangle {
        id: dropdown

        width: {
            const minWidth = 110
            const maxWidth = Math.min(600, root.width * 0.8)
            const hasIcon = root.currentValue && root.currentValue !== "" && root.optionIcons.length > 0 && root.options.indexOf(root.currentValue) >= 0 && root.optionIcons[root.options.indexOf(root.currentValue)] !== ""
            const iconWidth = hasIcon ? 20 + Theme.spacingM : 0
            const expandIconWidth = 18
            const textWidth = root.maxOptionTextWidth
            const horizontalPadding = root.dropdownHorizontalPadding * 2
            const spacing = Theme.spacingS
            const extraPadding = 6
            const contentWidth = textWidth + iconWidth + horizontalPadding + expandIconWidth + spacing + extraPadding
            return Math.max(minWidth, Math.min(maxWidth, contentWidth))
        }

        height: {
            const minHeight = root.controlHeight
            const maxHeight = 200
            const textHeight = textMetrics.boundingRect.height || textMetrics.height || Theme.fontSizeMedium * 1.5
            const iconHeight = 18
            const verticalPadding = root.dropdownVerticalPadding * 2
            const contentHeight = Math.max(textHeight, iconHeight) + verticalPadding
            return Math.max(minHeight, Math.min(maxHeight, contentHeight))
        }

        anchors.right: parent.right
        anchors.rightMargin: root.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        radius: 10
        color: dropdownArea.containsMouse ? Theme.primaryHover : Theme.contentBackground()
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, dropdownArea.containsMouse ? 0.18 : 0.1)
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing }
        }

        MouseArea {
            id: dropdownArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const popup = popupLoader.item
                if (!popup) return
                if (popup.showPopup) {
                    popup.close()
                    return
                }
                // Capture dropdown button's global position at click time —
                // mirrors TrayContextMenu passing anchorItem then calling
                // anchorItem.mapToGlobal inside updatePosition.
                const btnPos = dropdown.mapToGlobal(0, 0)
                popup.buttonGlobalPos = btnPos
                popup.buttonWidth     = dropdown.width
                popup.buttonHeight    = dropdown.height

                Quickshell.execDetached(["sh", "-c",
                    "echo 'CLICK btnPos=" + btnPos.x + "," + btnPos.y +
                    " btnW=" + dropdown.width + " btnH=" + dropdown.height + "' >> /tmp/ehdropdown.log"])

                // Set screen imperatively BEFORE showPopup = true
                let foundScreen = null
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    const s = Quickshell.screens[i]
                    Quickshell.execDetached(["sh", "-c",
                        "echo 'SCREEN[" + i + "] name=" + s.name +
                        " x=" + s.x + " y=" + s.y +
                        " w=" + s.width + " h=" + s.height + "' >> /tmp/ehdropdown.log"])
                    if (btnPos.x >= s.x && btnPos.x < s.x + s.width &&
                        btnPos.y >= s.y && btnPos.y < s.y + s.height) {
                        popup.screen = s
                        foundScreen = s
                        break
                    }
                }
                Quickshell.execDetached(["sh", "-c",
                    "echo 'FOUND=" + (foundScreen ? foundScreen.name : "NONE") + "' >> /tmp/ehdropdown.log"])
                popup.showPopup = true
            }
        }

        Row {
            id: contentRow
            anchors.left: parent.left
            anchors.right: expandIcon.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: root.dropdownHorizontalPadding
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingM

            Item {
                width: {
                    if (!root.currentValue || root.currentValue === "") return 0
                    const currentIndex = root.options.indexOf(root.currentValue)
                    if (currentIndex >= 0 && root.optionIcons.length > currentIndex && root.optionIcons[currentIndex] !== "" && root.width > 60) {
                        return 20
                    }
                    return 0
                }
                height: 20
                visible: width > 0

                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: {
                        const currentIndex = root.options.indexOf(root.currentValue)
                        const iconName = currentIndex >= 0 && root.optionIcons.length > currentIndex ? root.optionIcons[currentIndex] : ""
                        return iconName && iconName !== "" ? "image://icon/" + iconName : ""
                    }
                    sourceSize.width: 20
                    sourceSize.height: 20
                    fillMode: Image.PreserveAspectFit
                }
            }

            StyledText {
                id: dropdownText
                text: {
                    if (root.currentValue && root.currentValue !== "") {
                        return root.currentValue
                    }
                    return root.text
                }
                font.pixelSize: Theme.fontSizeMedium
                font.weight: (root.currentValue && root.currentValue !== "") ? Font.Normal : Font.Medium
                color: (root.currentValue && root.currentValue !== "") ? Theme.surfaceText : Theme.surfaceVariantText
                width: parent.width
                elide: Text.ElideNone
                horizontalAlignment: Text.AlignLeft
                clip: false
            }
        }

        EHIcon {
            id: expandIcon
            width: 20
            height: 20
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: root.dropdownHorizontalPadding
            name: "expand_more"
            size: 20
            color: Theme.surfaceText
            opacity: dropdownArea.containsMouse ? 1.0 : 0.6

            Behavior on opacity {
                NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing }
            }
        }
    }

    Loader {
        id: popupLoader

        property bool recreateFlag: root.forceRecreate

        active: true
        onRecreateFlagChanged: {
            active = false
            active = true
        }

        sourceComponent: Component {
            PanelWindow {
                id: dropdownMenu

                property string searchQuery: ""
                property var filteredOptions: []
                property int selectedIndex: -1
                readonly property string interFontFamily: root.interFontFamily
                property var fzfFinder: (function() {
                    try {
                        return Fzf.Finder(root.options, {
                            "selector": option => option,
                            "limit": 50,
                            "casing": "case-insensitive"
                        })
                    } catch (e) {
                        return null
                    }
                })()

                function updateFilteredOptions() {
                    if (!root.enableFuzzySearch || searchQuery.length === 0) {
                        filteredOptions = root.options
                        selectedIndex = -1
                        return
                    }
                    const results = fzfFinder.find(searchQuery)
                    filteredOptions = results.map(result => result.item)
                    selectedIndex = -1
                }

                function selectNext() {
                    if (filteredOptions.length === 0) return
                    selectedIndex = (selectedIndex + 1) % filteredOptions.length
                    listView.positionViewAtIndex(selectedIndex, ListView.Contain)
                }

                function selectPrevious() {
                    if (filteredOptions.length === 0) return
                    selectedIndex = selectedIndex <= 0 ? filteredOptions.length - 1 : selectedIndex - 1
                    listView.positionViewAtIndex(selectedIndex, ListView.Contain)
                }

                function selectCurrent() {
                    if (selectedIndex < 0 || selectedIndex >= filteredOptions.length) return
                    root.currentValue = filteredOptions[selectedIndex]
                    root.valueChanged(filteredOptions[selectedIndex])
                    close()
                }

                function close() {
                    showPopup = false
                    hideTimer.start()
                }

                WlrLayershell.namespace: "quickshell:dock:blur"
                WlrLayershell.layer: WlrLayershell.Overlay
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                visible: showPopup || popupBackground.opacity < 1
                color: "transparent"

                property bool showPopup: false

                // Screen is set imperatively in the click handler before showPopup = true,
                // exactly like TrayContextMenu sets menuWindow.screen = s before showMenu = true.
                // No declarative binding here — a binding would fight and override the
                // imperative assignment, always snapping back to screen[0].

                // The global position of the dropdown button, captured at click time.
                // Mirrors how TrayContextMenu stores anchorItem and calls
                // anchorItem.mapToGlobal inside updatePosition — one snapshot,
                // taken when the user actually clicks, not recomputed lazily.
                property point buttonGlobalPos: Qt.point(0, 0)
                property real  buttonWidth:     0
                property real  buttonHeight:    0

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                // Anchor point in screen-local coords — exactly the TrayContextMenu pattern:
                // call mapToGlobal on the trigger item, subtract screen.x/y to get
                // coords relative to this PanelWindow's top-left corner.
                property point anchorPos: Qt.point(screen.width / 2, screen.height / 2)

                function updatePosition() {
                    const scr = dropdownMenu.screen
                    const screenX = (scr && scr.x) ? scr.x : 0
                    const screenY = (scr && scr.y) ? scr.y : 0

                    const globalPos = dropdownMenu.buttonGlobalPos
                    const centerX = globalPos.x - screenX + dropdownMenu.buttonWidth / 2
                    const belowY  = globalPos.y - screenY + dropdownMenu.buttonHeight + 4

                    Quickshell.execDetached(["sh", "-c",
                        "echo 'UPDATEPOS globalPos=" + globalPos.x + "," + globalPos.y +
                        " screenX=" + screenX + " screenY=" + screenY +
                        " centerX=" + centerX + " belowY=" + belowY +
                        " screen=" + (scr ? scr.name : "null") + "' >> /tmp/ehdropdown.log"])

                    anchorPos = Qt.point(centerX, belowY)
                }

                // Debug: log coords so we can verify
                onAnchorPosChanged: {
                    if (showPopup)
                        Quickshell.execDetached(["sh", "-c",
                            "echo 'ANCHOR=" + anchorPos.x + "," + anchorPos.y +
                            " btnGlobal=" + buttonGlobalPos.x + "," + buttonGlobalPos.y +
                            " scr=" + (screen ? (screen.name + " x=" + screen.x + " y=" + screen.y) : "null") +
                            "' >> /tmp/ehdropdown.log"])
                }

                onVisibleChanged: {
                    if (visible) updatePosition()
                }

                onShowPopupChanged: {
                    if (showPopup) {
                        visible = true
                        searchQuery = ""
                        updateFilteredOptions()
                        updatePosition()
                        if (root.enableFuzzySearch && searchField.visible) {
                            searchField.forceActiveFocus()
                        }
                    } else {
                        popupBackground.opacity = 0
                        popupBackground.scale = 0.85
                    }
                }

                Timer {
                    id: hideTimer
                    interval: Theme.mediumDuration
                    repeat: false
                    onTriggered: {
                        dropdownMenu.visible = false
                        popupBackground.opacity = 1
                        popupBackground.scale = 1
                    }
                }

                Rectangle {
                    id: popupBackground
                    width: dropdownMenu.buttonWidth + root.popupWidthOffset
                    height: Math.min(root.maxPopupHeight, (root.enableFuzzySearch ? 40 + Theme.spacingS : 0) + Math.min(filteredOptions.length, 10) * 40 + Theme.spacingS * 2)

                    // Re-run updatePosition when our own size changes — mirrors TrayContextMenu
                    onWidthChanged:  dropdownMenu.updatePosition()
                    onHeightChanged: dropdownMenu.updatePosition()

                    // Declarative positioning — reacts to anchorPos automatically,
                    // including when the popup resizes (more items loaded, search filters).
                    // Matches the TrayContextMenu pattern exactly.
                    x: {
                        const scr = dropdownMenu.screen
                        // Centre the popup on the dropdown button
                        const want = dropdownMenu.anchorPos.x - width / 2
                        if (!scr) return want
                        return Math.max(10, Math.min(scr.width - width - 10, want))
                    }
                    y: {
                        const scr = dropdownMenu.screen
                        const below = dropdownMenu.anchorPos.y
                        if (!scr) return below
                        // Flip above the button if popup would go off the bottom
                        // "above" = anchorPos.y minus the full button height, popup height, and gap
                        const above = below - dropdownMenu.buttonHeight - height - 8
                        const targetY = (below + height > scr.height - 10) ? above : below
                        return Math.max(10, Math.min(scr.height - height - 10, targetY))
                    }

                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                    border.width: 1
                    radius: 12
                    opacity: 1
                    scale: 1

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 4
                        anchors.leftMargin: 2
                        anchors.rightMargin: -2
                        anchors.bottomMargin: -4
                        radius: parent.radius
                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                        z: parent.z - 1
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.emphasizedEasing }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS

                        Rectangle {
                            id: searchContainer
                            width: parent.width
                            height: 44
                            visible: root.enableFuzzySearch
                            radius: Theme.cornerRadius
                            color: Theme.surfaceVariantAlpha
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                            border.width: 1

                            EHTextField {
                                id: searchField
                                anchors.fill: parent
                                anchors.margins: 1
                                placeholderText: "Search..."
                                text: searchQuery
                                topPadding: Theme.spacingS
                                bottomPadding: Theme.spacingS
                                onTextChanged: {
                                    searchQuery = text
                                    updateFilteredOptions()
                                }
                                Keys.onDownPressed: selectNext()
                                Keys.onUpPressed: selectPrevious()
                                Keys.onReturnPressed: selectCurrent()
                                Keys.onEnterPressed: selectCurrent()
                                Keys.onEscapePressed: dropdownMenu.close()
                            }
                        }

                        Item {
                            width: 1
                            height: root.enableFuzzySearch ? Theme.spacingS : 0
                        }

                        EHListView {
                            id: listView
                            property var popupRef: dropdownMenu
                            width: parent.width
                            height: parent.height - (root.enableFuzzySearch ? searchContainer.height + Theme.spacingS : 0)
                            clip: true
                            model: filteredOptions
                            spacing: 2
                            interactive: true
                            flickDeceleration: 1500
                            maximumFlickVelocity: 2000
                            boundsBehavior: Flickable.DragAndOvershootBounds
                            boundsMovement: Flickable.FollowBoundsBehavior
                            pressDelay: 0
                            flickableDirection: Flickable.VerticalFlick

                            delegate: Rectangle {
                                property bool isSelected: selectedIndex === index
                                property bool isCurrentValue: root.currentValue === modelData
                                property int optionIndex: root.options.indexOf(modelData)

                                width: ListView.view.width
                                height: 38
                                radius: 8
                                color: isSelected ? Theme.primaryHover : optionArea.containsMouse ? Theme.primaryHoverLight : "transparent"
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, (isSelected || optionArea.containsMouse) ? 0.2 : 0.08)
                                border.width: (isSelected || optionArea.containsMouse) ? 1 : 0

                                Behavior on color {
                                    ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing }
                                }
                                Behavior on border.color {
                                    ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing }
                                }
                                Behavior on border.width {
                                    NumberAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing }
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingS

                                    Item {
                                        width: {
                                            if (optionIndex >= 0 && root.optionIcons.length > optionIndex && root.optionIcons[optionIndex] !== "") {
                                                return 20
                                            }
                                            return 0
                                        }
                                        height: 20
                                        visible: width > 0

                                        Image {
                                            anchors.centerIn: parent
                                            width: 20; height: 20
                                            source: {
                                                const iconName = optionIndex >= 0 && root.optionIcons.length > optionIndex ? root.optionIcons[optionIndex] : ""
                                                return iconName && iconName !== "" ? "image://icon/" + iconName : ""
                                            }
                                            sourceSize.width: 20; sourceSize.height: 20
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: isCurrentValue ? Font.Medium : Font.Normal
                                        color: isCurrentValue ? Theme.primary : Theme.surfaceText
                                        width: parent.parent.width - parent.x - (Theme.spacingL + Theme.spacingS)
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: optionArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentValue = modelData
                                        root.valueChanged(modelData)
                                        dropdownMenu.close()
                                    }
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    acceptedButtons: Qt.LeftButton
                    onClicked: function(mouse) {
                        const clickPos = mapToItem(popupBackground, mouse.x, mouse.y)
                        if (clickPos.x < 0 || clickPos.y < 0 ||
                            clickPos.x > popupBackground.width ||
                            clickPos.y > popupBackground.height) {
                            dropdownMenu.close()
                        }
                    }
                }
            }
        }
    }
}