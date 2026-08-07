import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Item {
    id: root

    // Unified scaling properties from DockWidgets
    property real widgetHeight: 30
    property real scaleFactor: widgetHeight / 40
    property real iconSize: 20
    property real fontSize: 13
    property real iconSpacing: 6
    property real padding: 8
    property bool isBarVertical: false
    
    readonly property string barPosition: SettingsData.minipanelPosition || "top"
    property bool isVertical: barPosition === "left" || barPosition === "right"
    property var axis: null
    property var parentWindow: null
    property var parentScreen: null
    property real widgetThickness: widgetHeight
    property real barThickness: widgetHeight
    readonly property real effectiveBarThickness: {
        let thickness = barThickness
        // Add Minipanel margins to get the effective bar thickness on screen
        if (barPosition === "top") thickness += SettingsData.minipanelTopMargin
        else if (barPosition === "bottom") thickness += SettingsData.minipanelTopMargin
        else if (barPosition === "left") thickness += SettingsData.minipanelLeftMargin
        else if (barPosition === "right") thickness += SettingsData.minipanelRightMargin
        return thickness
    }
    property bool isAtBottom: false
    readonly property real horizontalPadding: SettingsData.minipanelNoBackground ? 2 : Theme.spacingS
    readonly property var hiddenTrayIds: {
        const envValue = Quickshell.env("EH_HIDE_TRAYIDS") || ""
        return envValue ? envValue.split(",").map(id => id.trim().toLowerCase()) : []
    }
    readonly property var visibleTrayItems: {
        if (!hiddenTrayIds.length) {
            return SystemTray.items.values
        }
        return SystemTray.items.values.filter(item => {
            const itemId = item?.id || ""
            return !hiddenTrayIds.includes(itemId.toLowerCase())
        })
    }
    readonly property int calculatedSize: visibleTrayItems.length > 0 ? visibleTrayItems.length * (26 * scaleFactor) + horizontalPadding * 2 : 0
    readonly property real visualWidth: isVertical ? widgetHeight : calculatedSize
    readonly property real visualHeight: isVertical ? calculatedSize : widgetHeight

    width: isVertical ? barThickness : visualWidth
    height: isVertical ? visualHeight : widgetHeight
    visible: visibleTrayItems.length > 0

    Rectangle {
        id: visualBackground
        anchors.fill: parent
        radius: SettingsData.minipanelNoBackground ? 0 : Theme.widgetRadius * scaleFactor
        color: {
            if (visibleTrayItems.length === 0) {
                return "transparent";
            }
            if (SettingsData.minipanelNoBackground) {
                return "transparent";
            }
            const baseColor = Theme.widgetBaseBackgroundColor;
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
        }
    }

    Loader {
        id: layoutLoader

        anchors {
            top: root.barPosition === "top" ? parent.top : undefined
            bottom: root.barPosition === "bottom" ? parent.bottom : undefined
            left: root.barPosition === "left" ? parent.left : undefined
            right: root.barPosition === "right" ? parent.right : undefined

            horizontalCenter: root.isVertical ? parent.horizontalCenter : undefined
            verticalCenter: !root.isVertical ? parent.verticalCenter : undefined
        }

        sourceComponent: root.isVertical ? columnComp : rowComp
    }

    Component {
        id: rowComp
        Row {
            spacing: 0
            Repeater {
                model: root.visibleTrayItems
                delegate: Item {
                    id: delegateRoot
                    property var trayItem: modelData
                    property string iconSource: {
                        if (!trayItem) {
                            return "";
                        }

                        let icon = trayItem.icon;
                        if (typeof icon === 'string' || icon instanceof String) {
                            if (icon === "") {
                                return "";
                            }
                            if (icon.includes("?path=")) {
                                const split = icon.split("?path=");
                                if (split.length !== 2) {
                                    return icon;
                                }
                                const name = split[0];
                                const path = split[1];
                                let fileName = name.substring(name.lastIndexOf("/") + 1);
                                if (fileName.startsWith("dropboxstatus")) {
                                    fileName = `hicolor/16x16/status/${fileName}`;
                                }
                                return `file://${path}/${fileName}`;
                            }
                            if (icon.startsWith("/") && !icon.startsWith("file://")) {
                                return `file://${icon}`;
                            }
                            return icon;
                        }
                        return "";
                    }

                    width: 26 * root.scaleFactor
                    height: root.widgetHeight

                    Rectangle {
                        id: visualContent
                        width: 26 * root.scaleFactor
                        height: 26 * root.scaleFactor
                        anchors.centerIn: parent
                        radius: Theme.widgetRadius * root.scaleFactor
                        color: trayItemArea.containsMouse ? Theme.primaryHover : "transparent"

                        Item {
                            anchors.centerIn: parent
                            width: 20 * root.scaleFactor
                            height: 20 * root.scaleFactor
                            layer.enabled: SettingsData.systemIconTinting

                            IconImage {
                                anchors.centerIn: parent
                                width: 20 * root.scaleFactor
                                height: 20 * root.scaleFactor
                                source: delegateRoot.iconSource
                                asynchronous: true
                                smooth: true
                                mipmap: true
                            }

                            layer.effect: MultiEffect {
                                colorization: SettingsData.systemIconTinting ? SettingsData.iconTintIntensity : 0
                                colorizationColor: Theme.primary
                            }
                        }
                    }

                    MouseArea {
                        id: trayItemArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (!delegateRoot.trayItem) {
                                return;
                            }
                            if (mouse.button === Qt.LeftButton && !delegateRoot.trayItem.onlyMenu) {
                                delegateRoot.trayItem.activate();
                                return;
                            }
                            if (mouse.button === Qt.RightButton) {
                                const hasMenu = delegateRoot.trayItem.menu || delegateRoot.trayItem.hasMenu
                                if (delegateRoot.trayItem && hasMenu) {
                                    root.showForTrayItem(delegateRoot.trayItem, visualContent, parentScreen, root.barPosition, root.isVertical);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: columnComp
        Column {
            spacing: 0
            Repeater {
                model: root.visibleTrayItems
                delegate: Item {
                    id: delegateRoot
                    property var trayItem: modelData
                    property string iconSource: {
                        if (!trayItem) {
                            return "";
                        }

                        let icon = trayItem.icon;
                        if (typeof icon === 'string' || icon instanceof String) {
                            if (icon === "") {
                                return "";
                            }
                            if (icon.includes("?path=")) {
                                const split = icon.split("?path=");
                                if (split.length !== 2) {
                                    return icon;
                                }
                                const name = split[0];
                                const path = split[1];
                                let fileName = name.substring(name.lastIndexOf("/") + 1);
                                if (fileName.startsWith("dropboxstatus")) {
                                    fileName = `hicolor/16x16/status/${fileName}`;
                                }
                                return `file://${path}/${fileName}`;
                            }
                            if (icon.startsWith("/") && !icon.startsWith("file://")) {
                                return `file://${icon}`;
                            }
                            return icon;
                        }
                        return "";
                    }

                    width: root.widgetHeight
                    height: 26 * root.scaleFactor

                    Rectangle {
                        id: visualContent
                        width: 26 * root.scaleFactor
                        height: 26 * root.scaleFactor
                        anchors.centerIn: parent
                        radius: Theme.widgetRadius * root.scaleFactor
                        color: trayItemArea.containsMouse ? Theme.primaryHover : "transparent"

                        Item {
                            anchors.centerIn: parent
                            width: 20 * root.scaleFactor
                            height: 20 * root.scaleFactor
                            layer.enabled: SettingsData.systemIconTinting

                            IconImage {
                                anchors.centerIn: parent
                                width: 20 * root.scaleFactor
                                height: 20 * root.scaleFactor
                                source: delegateRoot.iconSource
                                asynchronous: true
                                smooth: true
                                mipmap: true
                            }

                            layer.effect: MultiEffect {
                                colorization: SettingsData.systemIconTinting ? SettingsData.iconTintIntensity : 0
                                colorizationColor: Theme.primary
                            }
                        }
                    }

                    MouseArea {
                        id: trayItemArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (!delegateRoot.trayItem) {
                                return;
                            }
                            if (mouse.button === Qt.LeftButton && !delegateRoot.trayItem.onlyMenu) {
                                delegateRoot.trayItem.activate();
                                return;
                            }
                            if (mouse.button === Qt.RightButton) {
                                const hasMenu = delegateRoot.trayItem.menu || delegateRoot.trayItem.hasMenu
                                if (delegateRoot.trayItem && hasMenu) {
                                    root.showForTrayItem(delegateRoot.trayItem, visualContent, parentScreen, root.barPosition, root.isVertical);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: trayContextMenuLoader
        source: "MiniPanelTrayContextMenu.qml"
        asynchronous: false

        onLoaded: {
        }

        onStatusChanged: {
            if (status === Loader.Error) {
                console.error("[SystemTrayBar] Failed to load TrayContextMenu:", source, errorString)
            }
        }
    }

    function showForTrayItem(trayItem, anchorItem, screen, barPosition, isVertical) {
        const realThickness = root.isVertical ? root.width : root.height
        const menuComponent = trayContextMenuLoader.item
        if (menuComponent && menuComponent.openForItem) {
            menuComponent.openForItem(trayItem, anchorItem, screen, barPosition, isVertical, realThickness)
        } else {
            console.error("[SystemTrayBar] TrayContextMenu not available or missing openForItem function")
        }
    }

    Component.onCompleted: {
        console.log("[SystemTrayBar] Initialized with barPosition:", barPosition, "isVertical:", isVertical, "SettingsData.minipanelPosition:", SettingsData.minipanelPosition)
    }

    Connections {
        target: SettingsData
        function onMinipanelPositionChanged() {
            console.log("[SystemTrayBar] SettingsData.minipanelPosition changed to:", SettingsData.minipanelPosition, "barPosition:", barPosition, "isVertical:", isVertical)
        }
    }
}