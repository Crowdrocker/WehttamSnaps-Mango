import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Widgets
import qs.Services

Item {
    id: userTab

    property var parentModal: null

    // ─── Info Row: label left, value right, both grow ───────────────────────
    component InfoRow : RowLayout {
        property string label: ""
        property string value: ""
        property bool showItem: true

        width: parent.width
        visible: showItem && value.length > 0
        spacing: Theme.spacingL

        StyledText {
            text: label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceVariantText
            Layout.preferredWidth: 160
            Layout.minimumWidth: 120
        }

        StyledText {
            text: value
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }

    // ─── Section Card ────────────────────────────────────────────────────────
    component SectionCard : Rectangle {
        property string sectionIcon: ""
        property string sectionTitle: ""
        default property alias contents: innerCol.data

        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.55)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
        height: outerCol.implicitHeight

        Column {
            id: outerCol
            width: parent.width
            spacing: 0

            // Header
            RowLayout {
                width: parent.width
                height: 44
                spacing: Theme.spacingS

                Rectangle {
                    width: 3
                    height: 16
                    radius: 2
                    color: Theme.primary
                    Layout.leftMargin: Theme.spacingL
                }

                EHIcon {
                    name: sectionIcon
                    size: 15
                    color: Theme.primary
                    visible: sectionIcon.length > 0
                }

                StyledText {
                    text: sectionTitle
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: 600
                    color: Theme.surfaceText
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
            }

            // Body
            Column {
                id: innerCol
                width: parent.width - Theme.spacingXL * 2
                x: Theme.spacingXL
                spacing: Theme.spacingM
                topPadding: Theme.spacingL
                bottomPadding: Theme.spacingL
            }
        }
    }

    // ─── Main Scroll Area ────────────────────────────────────────────────────
    EHFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: rootColumn.implicitHeight + Theme.spacingXL * 2
        contentWidth: width

        Column {
            id: rootColumn
            width: parent.width
            topPadding: Theme.spacingL
            bottomPadding: Theme.spacingL
            spacing: Theme.spacingM

            // ── Profile Header ────────────────────────────────────────────
            Rectangle {
                x: Theme.spacingL
                width: parent.width - Theme.spacingL * 2
                height: profileRow.implicitHeight + Theme.spacingXL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)

                Rectangle {
                    x: 0; y: Theme.cornerRadius
                    width: 3
                    height: parent.height - Theme.cornerRadius * 2
                    radius: 2
                    color: Theme.primary
                    opacity: 0.8
                }

                RowLayout {
                    id: profileRow
                    anchors {
                        fill: parent
                        topMargin: Theme.spacingXL
                        bottomMargin: Theme.spacingXL
                        leftMargin: Theme.spacingXL + Theme.spacingS
                        rightMargin: Theme.spacingXL
                    }
                    spacing: Theme.spacingXL

                    // Avatar
                    Rectangle {
                        Layout.preferredWidth: 84
                        Layout.preferredHeight: 84
                        Layout.alignment: Qt.AlignVCenter
                        radius: 42
                        color: Theme.surfaceContainerHigh
                        clip: true

                        EHIcon {
                            anchors.centerIn: parent
                            name: "person"
                            size: 48
                            color: Theme.primary
                            visible: !avatarEffect.visible
                        }

                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            source: {
                                if (PortalService.profileImage === "") return ""
                                if (PortalService.profileImage.startsWith("/")) return "file://" + PortalService.profileImage
                                return PortalService.profileImage
                            }
                            visible: false
                            fillMode: Image.PreserveAspectCrop
                        }

                        MultiEffect {
                            id: avatarEffect
                            anchors.fill: parent
                            source: avatarImage
                            visible: PortalService.profileImage !== "" && avatarImage.status === Image.Ready
                            maskEnabled: true
                            maskSource: avatarMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }

                        Item {
                            id: avatarMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false
                            Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
                        }
                    }

                    // Name block — fills all remaining space
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        StyledText {
                            text: "Welcome back"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: UserInfoService.fullName || UserInfoService.username || "User"
                            font.pixelSize: 42
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            lineHeight: 1.0
                        }

                        RowLayout {
                            spacing: Theme.spacingM
                            Layout.topMargin: 2

                            StyledText {
                                text: "@" + (HardwareService.hostname || "localhost")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.primary
                                font.family: "Monospace"
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: "·"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                opacity: 0.4
                                visible: (UserInfoService.uptime || "").length > 0
                            }

                            StyledText {
                                text: "up " + (UserInfoService.uptime || "")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                visible: (UserInfoService.uptime || "").length > 0
                            }
                        }
                    }

                    // Logo + version — center aligned
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                        Layout.preferredWidth: 280
                        spacing: Theme.spacingS

                        Image {
                            Layout.preferredWidth: 280
                            Layout.preferredHeight: 160
                            Layout.alignment: Qt.AlignHCenter
                            source: "../../assets/Event-Horizon-logo.png?v=" + Date.now()
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Event Horizon " + DotfilesUpdateService.releaseName + " — v" + DotfilesUpdateService.currentVersion
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            // ── Quick Stats Row ───────────────────────────────────────────
            RowLayout {
                x: Theme.spacingL
                width: parent.width - Theme.spacingL * 2
                spacing: Theme.spacingM

                component StatChip : Rectangle {
                    property string chipIcon: ""
                    property string chipLabel: ""
                    property string chipValue: ""

                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.55)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)

                    Column {
                        anchors.centerIn: parent
                        spacing: 5

                        RowLayout {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5

                            EHIcon {
                                name: chipIcon
                                size: 12
                                color: Theme.primary
                            }

                            StyledText {
                                text: chipLabel
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                font.weight: Font.Medium
                                font.letterSpacing: 0.8
                            }
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: chipValue
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: 600
                            color: Theme.surfaceText
                        }
                    }
                }

                StatChip {
                    chipIcon: "memory"
                    chipLabel: "MEMORY"
                    chipValue: HardwareService.usedMemory + " / " + HardwareService.totalMemory
                }
                StatChip {
                    chipIcon: "storage"
                    chipLabel: "DISK"
                    chipValue: HardwareService.diskUsed + " / " + HardwareService.diskTotal
                }
                StatChip {
                    chipIcon: "developer_board"
                    chipLabel: "KERNEL"
                    chipValue: (HardwareService.kernelVersion || "—").split("-")[0]
                }
            }

            // ── System ────────────────────────────────────────────────────
            SectionCard {
                x: Theme.spacingL
                width: parent.width - Theme.spacingL * 2
                sectionIcon: "computer"
                sectionTitle: "System"

                InfoRow { label: "OS";       value: HardwareService.osName || "—";        showItem: true }
                InfoRow { label: "Kernel";   value: HardwareService.kernelVersion || "—"; showItem: true }
                InfoRow { label: "Hostname"; value: HardwareService.hostname || "—";       showItem: true }
                InfoRow { label: "Uptime";   value: UserInfoService.uptime || "—";         showItem: true }
            }

            // ── Processor ─────────────────────────────────────────────────
            SectionCard {
                x: Theme.spacingL
                width: parent.width - Theme.spacingL * 2
                sectionIcon: "developer_board"
                sectionTitle: "Processor"

                InfoRow { label: "Model";        value: HardwareService.cpuModel || "—";       showItem: true }
                InfoRow { label: "Architecture"; value: HardwareService.cpuArchitecture || "";  showItem: (HardwareService.cpuArchitecture || "").length > 0 }
                InfoRow {
                    label: "Cores / Threads"
                    showItem: HardwareService.cpuCores > 0
                    value: {
                        var c = HardwareService.cpuCores
                        var t = HardwareService.cpuThreads
                        if (c > 0 && t > 0) return c + " cores  ·  " + t + " threads"
                        if (c > 0) return c + " cores"
                        return ""
                    }
                }
                InfoRow { label: "Frequency"; value: HardwareService.cpuFrequency || ""; showItem: (HardwareService.cpuFrequency || "").length > 0 }
            }

            // ── Memory ────────────────────────────────────────────────────
            SectionCard {
                x: Theme.spacingL
                width: parent.width - Theme.spacingL * 2
                sectionIcon: "memory"
                sectionTitle: "Memory"

                InfoRow { label: "Total";     value: HardwareService.totalMemory || "—";    showItem: true }
                InfoRow { label: "Used";      value: HardwareService.usedMemory || "";       showItem: (HardwareService.usedMemory || "").length > 0 }
                InfoRow { label: "Available"; value: HardwareService.availableMemory || "";  showItem: (HardwareService.availableMemory || "").length > 0 }
            }

            // ── Graphics ──────────────────────────────────────────────────
            SectionCard {
                x: Theme.spacingL
                width: parent.width - Theme.spacingL * 2
                sectionIcon: "videocam"
                sectionTitle: "Graphics"

                InfoRow { label: "Model";  value: HardwareService.gpuModel || "—";  showItem: true }
                InfoRow { label: "Driver"; value: HardwareService.gpuDriver || "";   showItem: (HardwareService.gpuDriver || "").length > 0 }
            }

            // ── Storage ───────────────────────────────────────────────────
            SectionCard {
                x: Theme.spacingL
                width: parent.width - Theme.spacingL * 2
                sectionIcon: "storage"
                sectionTitle: "Storage"

                InfoRow { label: "Total";     value: HardwareService.diskTotal || "—";       showItem: true }
                InfoRow { label: "Used";      value: HardwareService.diskUsed || "";          showItem: (HardwareService.diskUsed || "").length > 0 }
                InfoRow { label: "Available"; value: HardwareService.diskAvailable || "";     showItem: (HardwareService.diskAvailable || "").length > 0 }
                InfoRow { label: "Usage";     value: HardwareService.diskUsagePercent || "";  showItem: (HardwareService.diskUsagePercent || "").length > 0 }
            }

            // ── Refresh ───────────────────────────────────────────────────
            Item {
                x: Theme.spacingL
                width: parent.width - Theme.spacingL * 2
                height: 44

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 34
                    width: refreshInner.implicitWidth + Theme.spacingL * 2
                    radius: Theme.cornerRadius
                    color: refreshArea.containsMouse
                           ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                           : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.55)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b,
                                          refreshArea.containsMouse ? 0.45 : 0.22)

                    RowLayout {
                        id: refreshInner
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        EHIcon { name: "refresh"; size: 14; color: Theme.primary }

                        StyledText {
                            text: "Refresh"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            UserInfoService.refreshUserInfo()
                            HardwareService.refreshAll()
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing }
                    }
                }
            }
        }
    }
}