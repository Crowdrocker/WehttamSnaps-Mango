pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool disablePolkitIntegration: Quickshell.env("EH_DISABLE_POLKIT") === "1"

    property bool polkitAvailable: false
    property var agent: null

    function createPolkitAgent() {
        try {
            const qmlString = `
                import QtQuick
                import Quickshell.Services.Polkit

                PolkitAgent {}
            `
            agent = Qt.createQmlObject(qmlString, root, "PolkitService.Agent")
            polkitAvailable = true
        } catch (e) {
            polkitAvailable = false
        }
    }

    Component.onCompleted: {
        if (disablePolkitIntegration)
            return
        createPolkitAgent()
        if (!polkitAvailable)
            console.warn("PolkitService: Polkit not available (needs newer Quickshell or missing module).")
    }
}

