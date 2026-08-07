import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.ControlCenter.Components
import "../utils/layout.js" as LayoutUtils

Column {
    id: root

    property bool   editMode:             false
    property string expandedSection:      ""
    property int    expandedWidgetIndex:  -1
    property var    model:                null

    signal expandClicked(var widgetData, int globalIndex, real x, real y, real width, real height)
    signal removeWidget(int index)
    signal moveWidget(int fromIndex, int toIndex)
    signal toggleWidgetSize(int index)

    spacing: Theme.spacingM

    // Match TaskBar scaling: global UI × taskbar scale.
    readonly property real uiScale: (Appearance.combinedScale || 1) * (SettingsData.taskbarScale || 1)
    function spx(px) { return Math.round(px * uiScale) }

    readonly property var _ccLayout: LayoutUtils.calculateRowsAndWidgets(root, expandedSection, expandedWidgetIndex)
    readonly property int expandedRowIndex: _ccLayout.expandedRowIndex

    readonly property int   _cardRadius:      16
    readonly property real  _cardBorderAlpha: 0.08
    readonly property real  _cardBgAlpha:     0.28

    function getComponent(id, width) {
        if (id === "wifi" || id === "bluetooth" || id === "audioOutput" || id === "audioInput" || id === "volumeMixer" || id === "hdrToggle")
            return compoundPillComponent
        else if (id === "media")               return mediaPillComponent
        else if (id === "worldClocks")         return worldClocksComponent
        else if (id === "volumeSlider")        return audioSliderComponent
        else if (id === "brightnessSlider")    return brightnessSliderComponent
        else if (id === "inputVolumeSlider")   return inputAudioSliderComponent
        else if (id === "battery")
            return width <= 25 ? smallBatteryComponent : batteryPillComponent
        else if (id === "performance")         return performancePillComponent
        else if (id === "weather")             return weatherPillComponent
        else
            return width <= 25 ? smallToggleComponent : toggleButtonComponent
    }

    Repeater {
        model: root._ccLayout.rows

        Column {
            width: root.width
            spacing: Theme.spacingM
            property int rowIndex:    index
            property var rowWidgets:  modelData
            property bool isSliderOnlyRow: {
                const widgets = rowWidgets || []
                if (widgets.length === 0) return false
                return widgets.every(w => w.id === "volumeSlider" || w.id === "brightnessSlider" || w.id === "inputVolumeSlider")
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                Repeater {
                    model: rowWidgets || []

                    Item {
                        property var widgetData: modelData
                        property int globalWidgetIndex: {
                            const widgets = SettingsData.controlCenterWidgets || []
                            for (var i = 0; i < widgets.length; i++) {
                                if (widgets[i].id === modelData.id) return i
                            }
                            return -1
                        }
                        property int widgetWidth: {
                            const id = modelData.id || ""
                            if (id === "volumeMixer" || id === "media" || id === "weather") return 100
                            return modelData.width || 50
                        }

                        width: {
                            const baseWidth = root.width
                            const sp = Theme.spacingM
                            if (widgetWidth <= 25)      return (baseWidth - sp * 3) / 4
                            else if (widgetWidth <= 50) return (baseWidth - sp)     / 2
                            else if (widgetWidth <= 75) return (baseWidth - sp * 2) * 0.75
                            else                        return baseWidth
                        }

                        height: {
                            const id = (modelData.id || "")
                            const baseHeight = root.spx(56)
                            if (id === "brightnessSlider")                   return baseHeight
                            if (isSliderOnlyRow)                             return root.spx(18)
                            if (id === "audioOutput" || id === "audioInput") {
                                const h = widgetLoader.item ? widgetLoader.item.implicitHeight : 0
                                return Math.max(root.spx(104), h > 0 ? h : root.spx(104))
                            }
                            if (id === "volumeMixer") {
                                if (widgetLoader.item && widgetLoader.item.implicitHeight > 0)
                                    return widgetLoader.item.implicitHeight
                                const oc = (ApplicationAudioService.applicationStreams      || []).length
                                const ic = (ApplicationAudioService.applicationInputStreams || []).length
                                const shown = Math.min(oc + ic, 3)
                                return root.spx(36) + Theme.spacingXS + shown * root.spx(40) + Math.max(0, shown - 1) * Theme.spacingS
                                    + (oc + ic > 3 ? Theme.fontSizeSmall + root.spx(4) : 0)
                                    + Theme.spacingS
                            }
                            if (id === "worldClocks") {
                                if (widgetLoader.item && widgetLoader.item.implicitHeight > 0)
                                    return widgetLoader.item.implicitHeight
                                return root.spx(110)
                            }
                            if (id === "media")                              return root.spx(74)
                            if (id === "weather") {
                                if (widgetLoader.item && widgetLoader.item.implicitHeight > 0)
                                    return widgetLoader.item.implicitHeight
                                return root.spx(64)
                            }
                            if (id === "wifi" && NetworkService.networkStatus === "ethernet"
                                             && NetworkService.ethernetConnected)  return root.spx(68)
                            if (id === "bluetooth" && BluetoothService.available
                                                   && !!(BluetoothService.adapter && BluetoothService.adapter.enabled)) return root.spx(68)
                            return baseHeight
                        }

                        Loader {
                            id: widgetLoader
                            anchors.fill: parent
                            property var widgetData:       parent.widgetData
                            property int widgetIndex:      parent.globalWidgetIndex
                            property int globalWidgetIndex: parent.globalWidgetIndex
                            property int widgetWidth:      parent.widgetWidth
                            property int cardRadius:      root._cardRadius
                            property real cardBorderAlpha: root._cardBorderAlpha
                            property real cardBgAlpha:     root._cardBgAlpha
                            property bool editMode:       root.editMode
                            property var cardBg:         root._cardBg()
                            property var cardBorder:      root._cardBorder()
                            property var model:           root.model
                            property var gridRoot:        root

                            sourceComponent: root.getComponent((parent.widgetData || {}).id || "", parent.widgetWidth)

                            onLoaded: {
                                if (!item) return
                                // Pass shared widget context into extracted components (only if property exists)
                                if (item.widgetData !== undefined) item.widgetData = widgetLoader.widgetData
                                if (item.widgetIndex !== undefined) item.widgetIndex = widgetLoader.widgetIndex
                                if (item.globalWidgetIndex !== undefined) item.globalWidgetIndex = widgetLoader.globalWidgetIndex
                                if (item.widgetWidth !== undefined) item.widgetWidth = widgetLoader.widgetWidth
                                if (item.cardRadius !== undefined) item.cardRadius = widgetLoader.cardRadius
                                if (item.cardBorderAlpha !== undefined) item.cardBorderAlpha = widgetLoader.cardBorderAlpha
                                if (item.cardBgAlpha !== undefined) item.cardBgAlpha = widgetLoader.cardBgAlpha
                                if (item.editMode !== undefined) item.editMode = widgetLoader.editMode
                                if (item.cardBg !== undefined) item.cardBg = widgetLoader.cardBg
                                if (item.cardBorder !== undefined) item.cardBorder = widgetLoader.cardBorder
                                if (item.model !== undefined) item.model = widgetLoader.model
                                if (item.gridRoot !== undefined) item.gridRoot = widgetLoader.gridRoot
                            }
                        }
                    }
                }
            }

            DetailHost {
                id: detailHost
                width: parent.width
                height: active ? (detailHeight > 0 ? detailHeight + Theme.spacingS : 400) : 0
                property bool active: root.expandedSection !== "" && rowIndex === root.expandedRowIndex
                    && root.expandedSection !== "volumeMixer"
                    && root.expandedSection !== "weather"
                visible: active
                expandedSection: root.expandedSection
            }
        }
    }

    function _cardBg() {
        const alpha = Theme.getContentBackgroundAlpha() * root._cardBgAlpha
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
    }
    function _cardBorder() {
        return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, root._cardBorderAlpha)
    }

    // ─── Shared card appearance helper ────────────────────────────────────────
    function _cardBg_() {
        const alpha = Theme.getContentBackgroundAlpha() * root._cardBgAlpha
        return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, alpha)
    }
    function _cardBorder_() {
        return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, root._cardBorderAlpha)
    }

    // COMPOUND PILL - loads from file
    Component {
        id: compoundPillComponent
        CompoundPill {
            cardRadius: root._cardRadius
            cardBorderAlpha: root._cardBorderAlpha
            cardBgAlpha: root._cardBgAlpha
            editMode: root.editMode
            cardBg: root._cardBg_()
            cardBorder: root._cardBorder_()
            model: root.model
            gridRoot: root
        }
    }

    // MEDIA PILL
    Component {
        id: mediaPillComponent
        MediaPill {
            width:  parent.width
            height: parent.height
        }
    }

    // WORLD CLOCKS
    Component {
        id: worldClocksComponent
        WorldClocksCard {
            width:  parent.width
            height: parent.height
        }
    }

    // AUDIO SLIDER
    Component {
        id: audioSliderComponent
        AudioSliderRow {
            cardRadius: root._cardRadius
            cardBorderAlpha: root._cardBorderAlpha
            cardBgAlpha: root._cardBgAlpha
            editMode: root.editMode
            cardBg: root._cardBg_()
            cardBorder: root._cardBorder_()
            model: root.model
            gridRoot: root
        }
    }

    // BRIGHTNESS SLIDER
    Component {
        id: brightnessSliderComponent
        BrightnessSliderRow {
            cardRadius: root._cardRadius
            cardBorderAlpha: root._cardBorderAlpha
            cardBgAlpha: root._cardBgAlpha
            editMode: root.editMode
            cardBg: root._cardBg_()
            cardBorder: root._cardBorder_()
            model: root.model
            gridRoot: root
        }
    }

    // INPUT AUDIO SLIDER
    Component {
        id: inputAudioSliderComponent
        InputAudioSliderRow {
            cardRadius: root._cardRadius
            cardBorderAlpha: root._cardBorderAlpha
            cardBgAlpha: root._cardBgAlpha
            editMode: root.editMode
            cardBg: root._cardBg_()
            cardBorder: root._cardBorder_()
            model: root.model
            gridRoot: root
        }
    }

    // BATTERY PILL (full)
    Component {
        id: batteryPillComponent
        BatteryPill {
            cardRadius: root._cardRadius
            cardBorderAlpha: root._cardBorderAlpha
            cardBgAlpha: root._cardBgAlpha
            editMode: root.editMode
            cardBg: root._cardBg_()
            cardBorder: root._cardBorder_()
            model: root.model
            gridRoot: root
        }
    }

    // SMALL BATTERY
    Component {
        id: smallBatteryComponent
        SmallBattery {
            cardRadius: root._cardRadius
            cardBorderAlpha: root._cardBorderAlpha
            cardBgAlpha: root._cardBgAlpha
            editMode: root.editMode
            cardBg: root._cardBg_()
            cardBorder: root._cardBorder_()
            model: root.model
            gridRoot: root
        }
    }

    // PERFORMANCE PILL
    Component {
        id: performancePillComponent
        PerformancePill {
            cardRadius: root._cardRadius
            cardBorderAlpha: root._cardBorderAlpha
            cardBgAlpha: root._cardBgAlpha
            editMode: root.editMode
            cardBg: root._cardBg_()
            cardBorder: root._cardBorder_()
            model: root.model
            gridRoot: root
        }
    }

    // WEATHER PILL
    Component {
        id: weatherPillComponent
        WeatherPill {
            cardRadius: root._cardRadius
            cardBorderAlpha: root._cardBorderAlpha
            cardBgAlpha: root._cardBgAlpha
            editMode: root.editMode
            cardBg: root._cardBg_()
            cardBorder: root._cardBorder_()
            model: root.model
            gridRoot: root
        }
    }

    // TOGGLE BUTTON (full)
    Component {
        id: toggleButtonComponent
        ToggleButton {
            cardRadius: root._cardRadius
            cardBorderAlpha: root._cardBorderAlpha
            cardBgAlpha: root._cardBgAlpha
            editMode: root.editMode
            cardBg: root._cardBg_()
            cardBorder: root._cardBorder_()
            model: root.model
            gridRoot: root
        }
    }

    // SMALL TOGGLE
    Component {
        id: smallToggleComponent
        SmallToggle {
            cardRadius: root._cardRadius
            cardBorderAlpha: root._cardBorderAlpha
            cardBgAlpha: root._cardBgAlpha
            editMode: root.editMode
            cardBg: root._cardBg_()
            cardBorder: root._cardBorder_()
            model: root.model
            gridRoot: root
        }
    }
}