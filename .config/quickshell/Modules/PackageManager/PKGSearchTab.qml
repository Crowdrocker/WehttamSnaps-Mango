import QtQuick
import QtQuick.Layouts
import QtQuick.Controls   // Added for ScrollBar
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var parentModal: null

    property string searchQuery: ""
    onSearchQueryChanged: PackageManagerService.searchPackages(searchQuery)

    Connections {
        target: root.parentModal
        ignoreUnknownSignals: true
        function onClosingModal() {
            root.searchQuery = ""
        }
    }

    property var activeFilters: {
        const f = {}
        f["pacman"]  = PackageManagerService.pkgManager === "pacman"
        f["aur"]     = PackageManagerService.aurEnabled
        f["apt"]     = PackageManagerService.pkgManager === "apt"
        f["dnf"]     = PackageManagerService.pkgManager === "dnf"
        f["flatpak"] = PackageManagerService.flatpakAvailable
        return f
    }

    function filteredResults() {
        return PackageManagerService.searchResults.filter(p => {
            if (activeFilters[p.source] === false) return false
            return true
        })
    }

    function groupedResults() {
        const order = ["pacman", "aur", "apt", "dnf", "flatpak"]
        const groups = {}
        for (const pkg of filteredResults()) {
            if (!groups[pkg.source]) groups[pkg.source] = []
            groups[pkg.source].push(pkg)
        }
        return order
            .filter(s => groups[s] && groups[s].length > 0)
            .map(s => ({ source: s, packages: groups[s] }))
    }

    Column {
        anchors.fill:    parent
        anchors.topMargin: Theme.spacingM
        spacing: 0

        Item {
            width:  parent.width
            height: 56

            Rectangle {
                anchors {
                    fill:           parent
                    leftMargin:     Theme.spacingL
                    rightMargin:    Theme.spacingL
                    topMargin:      4
                    bottomMargin:   4
                }
                radius:       8
                color:        Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.30)
                border.color: searchInput.activeFocus
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                    : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors {
                        fill:         parent
                        leftMargin:   Theme.spacingM
                        rightMargin:  Theme.spacingM
                    }
                    spacing: Theme.spacingS

                    EHIcon {
                        name: PackageManagerService.isSearching ? "hourglass_empty" : "search"
                        size: Theme.iconSize
                        color: searchInput.activeFocus ? Theme.primary : Theme.surfaceVariantText
                        Layout.alignment: Qt.AlignVCenter
                        RotationAnimation on rotation {
                            running:  PackageManagerService.isSearching
                            loops:    Animation.Infinite
                            from: 0; to: 360
                            duration: 1200
                            easing.type: Easing.Linear
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TextInput {
                        id: searchInput
                        text: root.searchQuery
                        onTextChanged: root.searchQuery = text
                        Layout.fillWidth: true
                        font.pixelSize:   Theme.fontSizeLarge
                        color:            Theme.surfaceText
                        selectionColor:   Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                        clip:             true
                        focus:            true

                        StyledText {
                            visible:        searchInput.text === ""
                            text:           "Search packages…"
                            font.pixelSize: Theme.fontSizeLarge
                            color:          Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.35)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Keys.onEscapePressed: {
                            if (text !== "") { text = ""; return }
                            if (root.parentModal) root.parentModal.hide()
                        }
                    }

                    EHActionButton {
                        visible:   searchInput.text !== ""
                        circular:  false
                        iconName:  "close"
                        iconSize:  Theme.iconSize - 4
                        iconColor: Theme.surfaceVariantText
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: searchInput.text = ""
                    }
                }
            }
        }

        Item {
            width:  parent.width
            height: 40

            Row {
                anchors {
                    left:         parent.left
                    leftMargin:   Theme.spacingL
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.spacingXS

                Repeater {
                    model: {
                        const chips = []
                        if (PackageManagerService.pkgManager === "pacman") chips.push("pacman")
                        if (PackageManagerService.aurEnabled)              chips.push("aur")
                        if (PackageManagerService.pkgManager === "apt")   chips.push("apt")
                        if (PackageManagerService.pkgManager === "dnf")   chips.push("dnf")
                        if (PackageManagerService.flatpakAvailable)       chips.push("flatpak")
                        return chips
                    }

                    delegate: Item {
                        id: chip
                        required property string modelData
                        property bool active: root.activeFilters[modelData] !== false

                        function getChipColorValue(s) {
                            switch (s) {
                                case "pacman":  return "#74c0fc"
                                case "aur":     return "#a9e34b"
                                case "apt":     return "#FF9F43"
                                case "dnf":     return "#EF5350"
                                case "flatpak": return "#9775fa"
                                default:        return Theme.surfaceVariantText
                            }
                        }
                        readonly property string colorValue: getChipColorValue(modelData)

                        width:  chipLabel.implicitWidth + Theme.spacingM * 2
                        height: 26
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                        Rectangle {
                            anchors.fill: parent
                            radius:       height / 2
                            color: chip.active
                                ? Qt.rgba(Qt.color(chip.colorValue).r, Qt.color(chip.colorValue).g, Qt.color(chip.colorValue).b, 0.20)
                                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.15)
                            border.color: chip.active
                                ? Qt.rgba(Qt.color(chip.colorValue).r, Qt.color(chip.colorValue).g, Qt.color(chip.colorValue).b, 0.50)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        StyledText {
                            id: chipLabel
                            anchors.centerIn: parent
                            text:            modelData.toUpperCase()
                            font.pixelSize:  Theme.fontSizeXS
                            font.weight:     Font.Bold
                            font.letterSpacing: 0.6
                            color: chip.active ? chip.colorValue
                                : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.40)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                const f = Object.assign({}, root.activeFilters)
                                f[chip.modelData] = !chip.active
                                root.activeFilters = f
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.right:          parent.right
                anchors.rightMargin:    Theme.spacingL
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const n = root.filteredResults().length
                    if (n === 0 && searchInput.text === "") return ""
                    return n + " result" + (n === 1 ? "" : "s")
                }
                font.pixelSize: Theme.fontSizeSmall
                color:          Theme.surfaceVariantText
            }
        }

        // FIXED: Replaced EHFlickable with Flickable + ScrollBar
        Flickable {
            id: scroller
            width:         parent.width
            height:        parent.height - 56 - 40
            clip:          true
            contentHeight: resultsColumn.implicitHeight + Theme.spacingXL
            contentWidth:  width
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {}

            Column {
                id: resultsColumn
                width:        scroller.width
                spacing:      Theme.spacingL
                topPadding:   Theme.spacingS
                bottomPadding: Theme.spacingXL

                Item {
                    width:   parent.width
                    height:  240
                    visible: searchInput.text === "" && !PackageManagerService.isSearching

                    Column {
                        anchors.centerIn: parent
                        spacing:          Theme.spacingM

                        EHIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name:  "search"
                            size:  52
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.18)
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text:           "Type to search packages"
                            font.pixelSize: Theme.fontSizeLarge
                            color:          Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.35)
                        }
                    }
                }

                Item {
                    width:   parent.width
                    height:  200
                    visible: searchInput.text !== ""
                        && !PackageManagerService.isSearching
                        && root.filteredResults().length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM

                        EHIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name:  "search_off"
                            size:  48
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.20)
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text:           "No packages found"
                            font.pixelSize: Theme.fontSizeLarge
                            color:          Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.40)
                        }
                    }
                }

                Repeater {
                    model: root.groupedResults()

                    delegate: Item {
                        id: groupSection
                        required property var modelData
                        required property int index

                        width:  resultsColumn.width
                        height: sectionRect.implicitHeight + Theme.spacingS

                        function getGroupColorValue(s) {
                            switch (s) {
                                case "pacman":  return "#74c0fc"
                                case "aur":     return "#a9e34b"
                                case "apt":     return "#FF9F43"
                                case "dnf":     return "#EF5350"
                                case "flatpak": return "#9775fa"
                                default:        return Theme.surfaceVariantText
                            }
                        }

                        readonly property string colorValue: getGroupColorValue(modelData.source)

                        Rectangle {
                            id: sectionRect
                            width:  parent.width - Theme.spacingL * 2
                            x:      Theme.spacingL
                            implicitHeight: sectionContent.implicitHeight + Theme.spacingL * 2
                            radius: 10
                            color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                            border.color: Qt.rgba(
                                Qt.color(groupSection.colorValue).r,
                                Qt.color(groupSection.colorValue).g,
                                Qt.color(groupSection.colorValue).b, 0.20)
                            border.width: 1

                            Column {
                                id: sectionContent
                                anchors {
                                    left:       parent.left
                                    right:      parent.right
                                    top:        parent.top
                                    margins:    Theme.spacingL
                                }
                                spacing: Theme.spacingS

                                Row {
                                    width:   parent.width
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 28; height: 28
                                        radius: 7
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Qt.rgba(Qt.color(groupSection.colorValue).r, Qt.color(groupSection.colorValue).g, Qt.color(groupSection.colorValue).b, 0.15)
                                        border.color: Qt.rgba(Qt.color(groupSection.colorValue).r, Qt.color(groupSection.colorValue).g, Qt.color(groupSection.colorValue).b, 0.35)
                                        border.width: 1

                                        EHIcon {
                                            anchors.centerIn: parent
                                            name:  "inventory_2"
                                            size:  15
                                            color: groupSection.colorValue
                                        }
                                    }

                                    StyledText {
                                        text:            groupSection.modelData.source.toUpperCase()
                                        font.pixelSize:  Theme.fontSizeLarge
                                        font.weight:     Font.Medium
                                        color:           groupSection.colorValue
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Item { width: 1; height: 1; Layout.fillWidth: true }

                                    StyledText {
                                        text:           groupSection.modelData.packages.length + " packages"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color:          Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Repeater {
                                    model: groupSection.modelData.packages

                                    PKGCard {
                                        required property var modelData
                                        required property int index

                                        width:          sectionContent.width
                                        pkgName:        modelData.name        || ""
                                        pkgVersion:     modelData.version     || ""
                                        pkgSource:      modelData.source      || ""
                                        pkgDescription: modelData.description || ""
                                        pkgInstalled:   modelData.installed !== undefined ? modelData.installed : false
                                        animDelay:      index * 35

                                        isSelected: root.parentModal ? root.parentModal.isSelected(modelData) : false
                                        onClicked: {
                                            if (root.parentModal) {
                                                root.parentModal.togglePackage(modelData)
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
}
