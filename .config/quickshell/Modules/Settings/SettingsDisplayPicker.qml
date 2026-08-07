pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: root

    property var displayPreferences: []

    signal preferencesChanged(var preferences)

    property bool localAllDisplays: true

    onDisplayPreferencesChanged: {
        if (!Array.isArray(displayPreferences) || displayPreferences.length === 0) {
            localAllDisplays = true;
            return;
        }
        localAllDisplays = displayPreferences.includes("all");
    }

    width: parent?.width ?? 0
    height: displayColumn.implicitHeight

    Column {
        id: displayColumn
        width: parent.width
        anchors.top: parent.top
        spacing: Theme.spacingM

        EHToggle {
            width: parent.width
            text: "All displays"
            checked: root.localAllDisplays
            onToggled: isChecked => {
                root.localAllDisplays = isChecked;
                if (isChecked) {
                    root.preferencesChanged(["all"]);
                    return;
                }
                var screens = [];
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    var s = Quickshell.screens[i];
                    screens.push({
                        name: s.name,
                        model: s.model || ""
                    });
                }
                root.preferencesChanged(screens);
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            visible: !root.localAllDisplays

            Repeater {
                model: Quickshell.screens

                EHToggle {
                    required property var modelData

                    property bool localChecked: {
                        const prefs = root.displayPreferences;
                        if (!Array.isArray(prefs) || prefs.includes("all"))
                            return true;
                        return prefs.some(p => p.name === modelData.name);
                    }

                    width: parent.width
                    text: SettingsData.getScreenDisplayName(modelData)
                    description: modelData.width + "×" + modelData.height
                    checked: localChecked
                    onToggled: isChecked => {
                        localChecked = isChecked;
                        var prefs = JSON.parse(JSON.stringify(root.displayPreferences));
                        if (!Array.isArray(prefs) || prefs.includes("all"))
                            prefs = [];
                        prefs = prefs.filter(p => p.name !== modelData.name);
                        if (isChecked) {
                            prefs.push({
                                name: modelData.name,
                                model: modelData.model || ""
                            });
                        }
                        root.preferencesChanged(prefs);
                    }
                }
            }
        }
    }
}
