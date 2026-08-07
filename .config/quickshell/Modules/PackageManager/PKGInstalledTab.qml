import QtQuick
import QtQuick.Layouts
import QtQuick.Controls   // Required for ScrollBar
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var parentModal: null
    property string filterQuery: ""
    property string activeSource: "all"

    Component.onCompleted: {
        PackageManagerService.getInstalledPackages(false)
    }

    // Reactive computed properties — QML tracks installedPackages, filterQuery,
    // and activeSource as dependencies, re-evaluating automatically on any change.
    readonly property var filteredPackages: {
        let pkgs = PackageManagerService.installedPackages.slice()
        if (activeSource !== "all")
            pkgs = pkgs.filter(p => p.source === activeSource)
        if (filterQuery.trim() !== "") {
            const q = filterQuery.trim().toLowerCase()
            pkgs = pkgs.filter(p => p.name.toLowerCase().includes(q))
        }
        if (filterQuery.trim() === "") pkgs = pkgs.sort((a, b) => a.name.localeCompare(b.name))
        return pkgs
    }

    readonly property var groupedPackages: {
        const order = ["pacman", "aur", "apt", "dnf", "flatpak"]
        if (activeSource !== "all") {
            return [{ source: activeSource, packages: filteredPackages }]
        }
        const groups = {}
        for (const pkg of filteredPackages) {
            if (!groups[pkg.source]) groups[pkg.source] = []
            groups[pkg.source].push(pkg)
        }
        return order
            .filter(s => groups[s] && groups[s].length > 0)
            .map(s => ({ source: s, packages: groups[s] }))
    }

    function getSourceColorValue(s) {
        switch (s) {
            case "pacman":  return "#74c0fc"
            case "aur":     return "#a9e34b"
            case "apt":     return "#FF9F43"
            case "dnf":     return "#EF5350"
            case "flatpak": return "#9775fa"
            default:        return Theme.surfaceVariantText
        }
    }

    Column {
        anchors.fill:      parent
        anchors.topMargin: Theme.spacingM
        spacing:           0

        Item {
            width:  parent.width
            height: 52

            RowLayout {
                anchors {
                    fill:           parent
                    leftMargin:     Theme.spacingL
                    rightMargin:    Theme.spacingL
                    topMargin:      8
                    bottomMargin:   4
                }
                spacing: Theme.spacingM

                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: 8
                    color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.30)
                    border.color: filterInput.activeFocus
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: Theme.spacingS; rightMargin: Theme.spacingS }
                        spacing: Theme.spacingXS

                        EHIcon {
                            name:  "filter_list"
                            size:  16
                            color: filterInput.activeFocus ? Theme.primary : Theme.surfaceVariantText
                            Layout.alignment: Qt.AlignVCenter
                        }

                        TextInput {
                            id: filterInput
                            Layout.fillWidth: true
                            font.pixelSize:   Theme.fontSizeMedium
                            color:            Theme.surfaceText
                            clip:             true

                            StyledText {
                                visible:        filterInput.text === ""
                                text:           "Filter installed…"
                                font.pixelSize: Theme.fontSizeMedium
                                color:          Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.35)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            onTextChanged: root.filterQuery = text
                        }
                    }
                }

                Item {
                    width: 80; height: 34

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: refreshArea.containsMouse
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                            : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            EHIcon {
                                name:  "refresh"
                                size:  14
                                color: Theme.primary
                                Layout.alignment: Qt.AlignVCenter
                                RotationAnimation on rotation {
                                    running:  PackageManagerService.isLoading
                                    loops:    Animation.Infinite
                                    from: 0; to: 360
                                    duration: 1000
                                    easing.type: Easing.Linear
                                }
                            }

                            StyledText {
                                text:           PackageManagerService.isLoading ? "Loading" : "Refresh"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight:    Font.Medium
                                color:          Theme.primary
                            }
                        }

                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            enabled:      !PackageManagerService.isLoading
                            onClicked:    PackageManagerService.getInstalledPackages(true)
                        }
                    }
                }
            }
        }

        Item {
            width:  parent.width
            height: 38

            Row {
                anchors {
                    left:         parent.left
                    leftMargin:   Theme.spacingL
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.spacingXS

                Item {
                    property bool isActive: root.activeSource === "all"
                    width:  allChipLabel.implicitWidth + Theme.spacingM * 2
                    height: 26
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: parent.isActive
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                            : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.15)
                        border.color: parent.isActive
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    StyledText {
                        id: allChipLabel
                        anchors.centerIn: parent
                        text:            "ALL"
                        font.pixelSize:  Theme.fontSizeXS
                        font.weight:     Font.Bold
                        font.letterSpacing: 0.6
                        color: parent.isActive ? Theme.primary
                            : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    root.activeSource = "all"
                    }
                }

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
                        id: srcChip
                        required property string modelData
                        property bool isActive: root.activeSource === modelData
                        readonly property string chipColor: root.getSourceColorValue(modelData)

                        property int srcCount: PackageManagerService.installedPackages
                            .filter(p => p.source === modelData).length

                        width:  srcChipLabel.implicitWidth + (srcCount > 0 ? countBadge.width + 6 : 0) + Theme.spacingM * 2
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: srcChip.isActive
                                ? Qt.rgba(Qt.color(srcChip.chipColor).r, Qt.color(srcChip.chipColor).g, Qt.color(srcChip.chipColor).b, 0.20)
                                : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.15)
                            border.color: srcChip.isActive
                                ? Qt.rgba(Qt.color(srcChip.chipColor).r, Qt.color(srcChip.chipColor).g, Qt.color(srcChip.chipColor).b, 0.55)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            StyledText {
                                id: srcChipLabel
                                text:            srcChip.modelData.toUpperCase()
                                font.pixelSize:  Theme.fontSizeXS
                                font.weight:     Font.Bold
                                font.letterSpacing: 0.6
                                color: srcChip.isActive ? srcChip.chipColor
                                    : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.45)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                id: countBadge
                                visible: srcChip.srcCount > 0
                                width:  countText.implicitWidth + 6
                                height: 14
                                radius: 7
                                anchors.verticalCenter: parent.verticalCenter
                                color: srcChip.isActive
                                    ? Qt.rgba(Qt.color(srcChip.chipColor).r, Qt.color(srcChip.chipColor).g, Qt.color(srcChip.chipColor).b, 0.30)
                                    : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.12)

                                StyledText {
                                    id: countText
                                    anchors.centerIn: parent
                                    text:           srcChip.srcCount
                                    font.pixelSize: Theme.fontSizeXS - 1
                                    font.weight:    Font.Bold
                                    color: srcChip.isActive ? srcChip.chipColor
                                        : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.50)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    root.activeSource = srcChip.modelData
                        }
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const n = root.filteredPackages.length
                        return n + " package" + (n === 1 ? "" : "s")
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color:          Theme.surfaceVariantText
                }
            }
        }

        // FIXED: Replaced EHFlickable with standard Flickable + ScrollBar
        Flickable {
            id: scroller
            width:         parent.width
            height:        parent.height - 52 - 38
            clip:          true
            contentHeight: listColumn.implicitHeight + Theme.spacingXL
            contentWidth:  width
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {}

            Column {
                id: listColumn
                width:         scroller.width
                spacing:       Theme.spacingL
                topPadding:    Theme.spacingS
                bottomPadding: Theme.spacingXL

                Item {
                    width:   parent.width
                    height:  200
                    visible: PackageManagerService.isLoading

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM

                        EHIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name:  "hourglass_empty"
                            size:  48
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.25)
                            RotationAnimation on rotation {
                                running:  PackageManagerService.isLoading
                                loops:    Animation.Infinite
                                from: 0; to: 360
                                duration: 1200
                                easing.type: Easing.Linear
                            }
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text:           PackageManagerService.currentOperation || "Loading packages…"
                            font.pixelSize: Theme.fontSizeMedium
                            color:          Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.40)
                        }
                    }
                }

                Item {
                    width:   parent.width
                    height:  200
                    visible: !PackageManagerService.isLoading
                        && root.filteredPackages.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM

                        EHIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name:  "inventory_2"
                            size:  48
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.18)
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text:           root.filterQuery !== "" ? "No matching packages" : "No packages found"
                            font.pixelSize: Theme.fontSizeLarge
                            color:          Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.35)
                        }
                    }
                }

                Repeater {
                    model: !PackageManagerService.isLoading ? root.groupedPackages : []

                    delegate: Item {
                        id: instGroup
                        required property var modelData
                        required property int index

                        readonly property string groupColor: root.getSourceColorValue(modelData.source)

                        width:  listColumn.width
                        height: instSectionRect.implicitHeight + Theme.spacingS

                        Rectangle {
                            id: instSectionRect
                            width:  parent.width - Theme.spacingL * 2
                            x:      Theme.spacingL
                            implicitHeight: instSectionCol.implicitHeight + Theme.spacingL * 2
                            radius: 10
                            color:  Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)
                            border.color: Qt.rgba(
                                Qt.color(instGroup.groupColor).r,
                                Qt.color(instGroup.groupColor).g,
                                Qt.color(instGroup.groupColor).b, 0.18)
                            border.width: 1

                            Column {
                                id: instSectionCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacingL }
                                spacing: Theme.spacingS

                                RowLayout {
                                    width: parent.width
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        width: 28; height: 28; radius: 7
                                        Layout.alignment: Qt.AlignVCenter
                                        color: Qt.rgba(Qt.color(instGroup.groupColor).r, Qt.color(instGroup.groupColor).g, Qt.color(instGroup.groupColor).b, 0.15)
                                        border.color: Qt.rgba(Qt.color(instGroup.groupColor).r, Qt.color(instGroup.groupColor).g, Qt.color(instGroup.groupColor).b, 0.35)
                                        border.width: 1

                                        EHIcon {
                                            anchors.centerIn: parent
                                            name: {
                                                switch (instGroup.modelData.source) {
                                                    case "pacman":  return "deployed_code"
                                                    case "aur":     return "code"
                                                    case "apt":     return "terminal"
                                                    case "dnf":     return "package_2"
                                                    case "flatpak": return "apps"
                                                    default:        return "inventory_2"
                                                }
                                            }
                                            size:  15
                                            color: instGroup.groupColor
                                        }
                                    }

                                    StyledText {
                                        text:            instGroup.modelData.source.toUpperCase()
                                        font.pixelSize:  Theme.fontSizeLarge
                                        font.weight:     Font.Medium
                                        color:           instGroup.groupColor
                                        Layout.fillWidth: true
                                    }

                                    StyledText {
                                        text:           instGroup.modelData.packages.length + " installed"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color:          Theme.surfaceVariantText
                                    }
                                }

                                Repeater {
                                    model: instGroup.modelData.packages

                                    PKGCard {
                                        required property var modelData
                                        required property int index
                                        width:          instSectionCol.width
                                        pkgName:        modelData.name        || ""
                                        pkgVersion:     modelData.version     || ""
                                        pkgSource:      modelData.source      || ""
                                        pkgDescription: modelData.description || ""
                                        pkgInstalled:   true   // These are installed packages
                                        animDelay:      index * 25
                                        isSelected: root.parentModal ? root.parentModal.isSelected(modelData) : false
                                        onClicked: {
                                            if (root.parentModal) {
                                                // Ensure installed:true is set so the action bar
                                                // correctly counts this as a removal, not an install
                                                const pkg = Object.assign({}, modelData, { installed: true })
                                                root.parentModal.togglePackage(pkg)
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
