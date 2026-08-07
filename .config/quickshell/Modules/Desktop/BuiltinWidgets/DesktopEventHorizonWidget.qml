// Event Horizon — weather from qs.Modules.Weather (WeatherDashEmbed); media/calendar/clock/fastfetch unchanged.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Desktop

Item {
    id: root

    anchors.fill: parent

    property string instanceId: ""
    property var instanceData: null
    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    property real widgetWidth: 720
    property real widgetHeight: 520
    property real defaultWidth: 720
    property real defaultHeight: 520
    property real minWidth: 420
    property real minHeight: 320

    readonly property bool ehShowingHome: root.stackPageIndex === 0
    implicitWidth: widgetWidth
    implicitHeight: ehShowingHome
        ? Math.ceil(Theme.spacingL * 2 + ehHeaderColumn.implicitHeight + Theme.spacingM + homeRow.implicitHeight)
        : defaultHeight

    property int currentTabIndex: 0

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property real ui: Appearance.combinedScale || 1
    function spx(px) { return Math.round(px * ui) }

    readonly property real transparency: isInstance ? (cfg.transparency ?? 0.95) : SettingsData.desktopEventHorizonTransparency
    readonly property real contentBackgroundOpacity: isInstance ? (cfg.contentBackgroundOpacity ?? 1.0) : SettingsData.desktopEventHorizonContentBackgroundOpacity
    readonly property real borderOpacity: isInstance ? (cfg.borderOpacity ?? 0.12) : SettingsData.desktopEventHorizonBorderOpacity
    readonly property real borderThickness: isInstance ? (cfg.borderThickness ?? 1) : SettingsData.desktopEventHorizonBorderThickness
    readonly property real tabBarOpacity: isInstance ? (cfg.tabBarOpacity ?? 1.0) : SettingsData.desktopEventHorizonTabBarOpacity
    readonly property real animatedTintOpacity: isInstance ? (cfg.animatedTintOpacity ?? 0.04) : SettingsData.desktopEventHorizonAnimatedTintOpacity
    /// Panel / card fill multiplier (main shell, tabs, tiles). Icons & labels stay solid.
    /// Instance: use config when set; otherwise follow the dash Settings slider (same as non-instance).
    readonly property real chromeBackgroundOpacity: {
        if (!isInstance)
            return SettingsData.desktopEventHorizonChromeBackgroundOpacity
        const v = cfg.chromeBackgroundOpacity
        if (v !== undefined && v !== null)
            return v
        return SettingsData.desktopEventHorizonChromeBackgroundOpacity
    }

    readonly property var tabModel: {
        const t = [
            { label: "Home", icon: "home" },
            { label: "Media", icon: "music_note" },
        ]
        if (SettingsData.weatherEnabled)
            t.push({ label: "Weather", icon: "wb_sunny" })
        t.push({ label: "Calendar", icon: "calendar_today" })
        t.push({ label: "Settings", icon: "settings" })
        return t
    }

    // Tab bar skips Weather when disabled; stack keeps a fixed slot (index 2) so map tab → page.
    // Stack: 0 Home, 1 Media, 2 Weather, 3 Calendar, 4 Settings mini.
    readonly property int stackPageIndex: {
        if (SettingsData.weatherEnabled)
            return root.currentTabIndex
        if (root.currentTabIndex <= 1)
            return root.currentTabIndex
        if (root.currentTabIndex === 2)
            return 3
        return 4
    }

    Connections {
        target: SettingsData
        function onWeatherEnabledChanged() {
            if (SettingsData.weatherEnabled)
                return
            if (root.currentTabIndex === 2)
                root.currentTabIndex = 1
            else if (root.currentTabIndex >= 3)
                root.currentTabIndex -= 1
        }
    }

    Rectangle {
        id: shell
        anchors.fill: parent
        radius: Theme.cornerRadius + 6
        // Fill alpha only (no Item.opacity) so inner text/icons stay sharp. Includes main outer panel.
        readonly property real _fillA: Math.min(1, Math.max(0,
            root.contentBackgroundOpacity * root.transparency * root.chromeBackgroundOpacity))
        color: Qt.rgba(
            Theme.surfaceContainer.r,
            Theme.surfaceContainer.g,
            Theme.surfaceContainer.b,
            _fillA
        )
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, root.borderOpacity)
        border.width: root.borderThickness
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(Theme.surfaceTint.r, Theme.surfaceTint.g, Theme.surfaceTint.b, 1.0)
            opacity: root.animatedTintOpacity
            visible: root.animatedTintOpacity > 0
            enabled: false
            z: -1
            SequentialAnimation on opacity {
                running: root.animatedTintOpacity > 0 && SettingsData.darkDashTintAnimateEnabled
                loops: Animation.Infinite
                NumberAnimation {
                    to: Math.min(1.0, root.animatedTintOpacity * 2.2)
                    duration: Theme.extraLongDuration
                    easing.type: Theme.standardEasing
                }
                NumberAnimation {
                    to: Math.max(0.0, root.animatedTintOpacity * 0.4)
                    duration: Theme.extraLongDuration
                    easing.type: Theme.standardEasing
                }
            }
        }

        ColumnLayout {
            id: chrome
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM
            z: 1

            ColumnLayout {
                id: ehHeaderColumn
                Layout.fillWidth: true
                spacing: Theme.spacingS

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    EHIcon {
                        name: "blur_circular"
                        size: Math.round(22 * (Appearance.combinedScale || 1))
                        color: Theme.primary
                        Layout.alignment: Qt.AlignVCenter
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: "Event Horizon"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.DemiBold
                        color: Theme.surfaceText
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    opacity: root.tabBarOpacity
                    z: 2

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Math.min(1, 0.55 * root.chromeBackgroundOpacity))
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                        border.width: 1
                    }

                    // Uniform inset so tabs + selection pills never hug / clip the outer pill edge.
                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        height: parent.height - 12
                        spacing: Theme.spacingXS
                        z: 1

                        Repeater {
                            model: root.tabModel

                            Item {
                                required property int index
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readonly property bool tabSelected: root.currentTabIndex === index
                                readonly property color labelColor: tabSelected
                                    ? Theme.primary
                                    : Theme.surfaceText

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    radius: height / 2
                                    color: tabSelected
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, Math.min(1, 0.18 * root.chromeBackgroundOpacity))
                                        : "transparent"
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS
                                    z: 1

                                    EHIcon {
                                        visible: !!(modelData && modelData.icon)
                                        name: (modelData && modelData.icon) ? modelData.icon : "circle"
                                        size: 16
                                        color: labelColor
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    StyledText {
                                        text: (modelData && modelData.label !== undefined) ? modelData.label : ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: tabSelected ? Font.DemiBold : Font.Medium
                                        color: labelColor
                                        Layout.alignment: Qt.AlignVCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    z: 10
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.currentTabIndex = index
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                StackLayout {
                    anchors.fill: parent
                    currentIndex: root.stackPageIndex

                    Item {
                        RowLayout {
                            id: homeRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: Theme.spacingM

                            ColumnLayout {
                                id: homeLeftColumn
                                Layout.preferredWidth: 180
                                Layout.minimumWidth: 160
                                Layout.maximumWidth: 210
                                Layout.fillHeight: false
                                Layout.alignment: Qt.AlignTop
                                spacing: Theme.spacingS

                                readonly property real homeTileH: Math.min(240, Math.max(180, width > 0 ? width : 220))

                                // Clock — same tile height as media; top-aligned so card tops match the media card.
                                Item {
                                    id: homeClockHost
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 210
                                    Layout.minimumWidth: 160
                                    Layout.preferredHeight: homeLeftColumn.homeTileH
                                    clip: true

                                    MacOSClockWidget {
                                        anchors.top: parent.top
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Math.min(parent.width, parent.height)
                                        height: width
                                        widgetWidth: width
                                        widgetHeight: height
                                        semiRoundedCard: true
                                        chromeBackgroundOpacityScale: root.chromeBackgroundOpacity
                                    }
                                }

                                // Compact now-playing — square tile same size logic as clock (not full column height).
                                Item {
                                    id: homeMediaHost
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 210
                                    Layout.minimumWidth: 160
                                    Layout.preferredHeight: homeLeftColumn.homeTileH
                                    Layout.alignment: Qt.AlignHCenter
                                    clip: true

                                    MediaPopupContent {
                                        anchors.fill: parent
                                        showCloseButton: false
                                        clockCardChrome: true
                                        semiRoundedChrome: true
                                        chromeBackgroundOpacityScale: root.chromeBackgroundOpacity
                                        activePlayer: MprisController.activePlayer
                                        ui: root.ui * Math.max(0.48, Math.min(0.82, Math.max(homeMediaHost.width, 140) / 255))
                                        fillScale: Math.max(0.26, Math.min(0.56, Math.max(homeMediaHost.width, 140) / 420))
                                        transportBoost: 1.52
                                    }
                                }

                                // Calendar — third square; same card chrome as MacOSClockWidget / home media.
                                Rectangle {
                                    id: homeCalCard
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 210
                                    Layout.minimumWidth: 160
                                    Layout.preferredHeight: homeLeftColumn.homeTileH
                                    Layout.alignment: Qt.AlignHCenter
                                    radius: width > 0 && height > 0
                                            ? Math.min(20, Math.min(width, height) * 0.11)
                                            : 12
                                    color: Qt.rgba(
                                        Theme.surfaceContainer.r,
                                        Theme.surfaceContainer.g,
                                        Theme.surfaceContainer.b,
                                        Math.min(1, 0.88 * root.chromeBackgroundOpacity)
                                    )
                                    border.color: Qt.rgba(
                                        Theme.outline.r,
                                        Theme.outline.g,
                                        Theme.outline.b,
                                        SettingsData.desktopWidgetBorderOpacity !== undefined
                                        ? SettingsData.desktopWidgetBorderOpacity
                                        : 0.22
                                    )
                                    border.width: Math.max(
                                        1,
                                        SettingsData.desktopWidgetBorderThickness !== undefined
                                        ? SettingsData.desktopWidgetBorderThickness
                                        : 1
                                    )
                                    antialiasing: true
                                    clip: true

                                    DashCalendarEmbed {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingXS
                                        squareHomeEmbed: true
                                    }
                                }
                            }

                            Item {
                                id: homeFastfetchHost
                                Layout.fillWidth: true
                                Layout.fillHeight: false
                                Layout.alignment: Qt.AlignTop
                                readonly property real _alignH: Math.max(
                                    dashFastfetch.implicitHeight,
                                    homeLeftColumn.implicitHeight
                                ) + 8
                                implicitHeight: _alignH
                                height: _alignH
                                clip: true

                                DesktopFastfetchWidgetSimple {
                                    id: dashFastfetch
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    naturalHeightMode: true
                                    hideNetwork: true
                                    suppressCardBorder: true
                                    chromeBackgroundOpacityScale: root.chromeBackgroundOpacity
                                    widgetWidth: width
                                    widgetHeight: height
                                }
                            }
                        }
                    }

                    Item {
                        clip: true
                        // Do not wrap in Flickable: it steals presses from play/seek MouseAreas (Qt flicks vs click).
                        MediaPopupContent {
                            id: mediaBody
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            chromeBackgroundOpacityScale: root.chromeBackgroundOpacity
                            activePlayer: MprisController.activePlayer
                            ui: root.ui
                            fillScale: Math.min(
                                Math.max(parent.width, 1) / 400,
                                Math.max(parent.height, 1) / 260,
                                1.55
                            )
                            showCloseButton: false
                        }
                    }

                    Item {
                        clip: true

                        DashWeatherEmbed {
                            id: weatherBody
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            visible: SettingsData.weatherEnabled
                        }
                        StyledText {
                            anchors.centerIn: parent
                            visible: !SettingsData.weatherEnabled
                            horizontalAlignment: Text.AlignHCenter
                            text: "Weather is off in Settings."
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    Item {
                        DashCalendarEmbed {
                            anchors.fill: parent
                        }
                    }

                    Item {
                        clip: true

                        EventHorizonSettingsMini {
                            anchors.fill: parent
                        }
                    }
                }
            }
        }
    }
}
