import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common

Window {
    id: root

    property string title: ""
    property size minimumSize: Qt.size(200, 150)
    property size maximumSize: Qt.size(0, 0) // 0 means unlimited
    property color backgroundColor: Theme.surfaceContainer
    property bool maximized: false
    property real implicitWidth: 800
    property real implicitHeight: 600

    function startSystemMove() {
        if (typeof root.startMove === "function") {
            root.startMove();
        } else if (typeof root.requestMove === "function") {
            root.requestMove();
        }
    }

    function startSystemResize(edges) {
        if (typeof root.startResize === "function") {
            root.startResize(edges);
        } else if (typeof root.requestResize === "function") {
            root.requestResize(edges);
        }
    }

    width: implicitWidth
    height: implicitHeight
    visible: false
    color: "transparent"


    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.backgroundColor.r, root.backgroundColor.g, root.backgroundColor.b, (typeof SettingsData !== "undefined" && SettingsData.modalTransparency !== undefined) ? SettingsData.modalTransparency : 0.85)
    }

    onMaximizedChanged: {
        if (maximized) {
            if (typeof root.setMaximized === "function") {
                root.setMaximized(true);
            } else if (typeof root.requestMaximize === "function") {
                root.requestMaximize();
            }
        } else {
            if (typeof root.setMaximized === "function") {
                root.setMaximized(false);
            } else if (typeof root.requestUnmaximize === "function") {
                root.requestUnmaximize();
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            if (!root) return;
            if (typeof root.setTitle === "function" && root.title) {
                root.setTitle(root.title);
            }
            if (typeof root.setMinSize === "function") {
                root.setMinSize(root.minimumSize.width, root.minimumSize.height);
            }
            if (root.maximumSize.width > 0 && root.maximumSize.height > 0) {
                if (typeof root.setMaxSize === "function") {
                    root.setMaxSize(root.maximumSize.width, root.maximumSize.height);
                }
            }
        });
    }

    onTitleChanged: {
        if (typeof root.setTitle === "function") {
            root.setTitle(root.title);
        }
    }

    onMinimumSizeChanged: {
        if (typeof root.setMinSize === "function") {
            root.setMinSize(root.minimumSize.width, root.minimumSize.height);
        }
    }

    onMaximumSizeChanged: {
        if (root.maximumSize.width > 0 && root.maximumSize.height > 0) {
            if (typeof root.setMaxSize === "function") {
                root.setMaxSize(root.maximumSize.width, root.maximumSize.height);
            }
        } else if (typeof root.setMaxSize === "function") {
            root.setMaxSize(0, 0); // Unlimited
        }
    }
}
