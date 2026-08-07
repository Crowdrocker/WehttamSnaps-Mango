import QtQuick
import QtCore
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property var modelData: null
    property var screen: modelData
    property real widgetWidth: SettingsData.desktopWidgetWidth
    property real widgetHeight: SettingsData.desktopWidgetHeight
    property bool alwaysVisible: true
    property string position: "top-center"
    property var positioningBox: null
    
    property real currentGpuTemperature: getSelectedGpuTemperature()

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight
    visible: alwaysVisible

    WlrLayershell.layer: WlrLayershell.Background
    WlrLayershell.namespace: "quickshell:dock:blur"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        left: position.includes("left") ? true : false
        right: position.includes("right") ? true : false
        top: position.includes("top") ? true : false
        bottom: position.includes("bottom") ? true : false
    }

    readonly property bool isBarVertical: SettingsData.topBarPosition === "left" || SettingsData.topBarPosition === "right"
    readonly property real barExclusiveSize: SettingsData.topBarVisible && !SettingsData.topBarFloat ? ((SettingsData.topBarHeight * SettingsData.topbarScale) + SettingsData.topBarSpacing + (SettingsData.topBarGothCornersEnabled ? Theme.cornerRadius : 0)) : 0
    
    margins {
        left: {
            var base = position.includes("left") ? 20 : 0
            if (SettingsData.topBarPosition === "left" && !SettingsData.topBarFloat) {
                return base + barExclusiveSize
            }
            return base
        }
        right: {
            var base = position.includes("right") ? 20 : 0
            if (SettingsData.topBarPosition === "right" && !SettingsData.topBarFloat) {
                return base + barExclusiveSize
            }
            return base
        }
        top: {
            var base = position.includes("top") ? (SettingsData.topBarHeight + SettingsData.topBarSpacing + SettingsData.topBarBottomGap + 20) : 0
            if (SettingsData.topBarPosition === "top" && !SettingsData.topBarFloat) {
                return base
            }
            return position.includes("top") ? 20 : 0
        }
        bottom: {
            var base = position.includes("bottom") ? (SettingsData.dockExclusiveZone + SettingsData.dockBottomGap + 20) : 0
            if (SettingsData.topBarPosition === "bottom" && !SettingsData.topBarFloat) {
                return base + barExclusiveSize
            }
            return base
        }
    }

    Component.onCompleted: {
        DgopService.addRef(["gpu"]);
        
        // Delay starting GPU monitoring to ensure processes are initialized
        Qt.callLater(() => {
            startNvmlMonitoring();
        });
    }

    Connections {
        target: DgopService
        function onAvailableGpusChanged() {
            currentGpuTemperature = getSelectedGpuTemperature();
        }
    }

    Connections {
        target: SettingsData
        function onDesktopGpuSelectionChanged() {
            currentGpuTemperature = getSelectedGpuTemperature();
        }
    }

    function startNvmlMonitoring() {
        if (nvmlGpuProcess.running) {
            return;
        }
        nvmlGpuProcess.running = true;
        intelGpuProcess.running = true;
    }

    function getSelectedGpuTemperature() {
        if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
            return -1;
        }
        
        if (SettingsData.desktopGpuSelection === "auto") {
            const gpu = DgopService.availableGpus[0];
            const temp = gpu.temperature !== undefined ? gpu.temperature : -1;
            return temp;
        }
        
        const options = SettingsData.getGpuDropdownOptions();
        const selectedIndex = options.indexOf(SettingsData.desktopGpuSelection);
        
        if (selectedIndex > 0 && selectedIndex <= DgopService.availableGpus.length) {
            const gpuIndex = selectedIndex - 1;
            const gpu = DgopService.availableGpus[gpuIndex];
            const temp = gpu.temperature || -1;
            return temp;
        }
        
        return -1;
    }
    
    Component.onDestruction: {
        DgopService.removeRef(["gpu"]);
    }

    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
    readonly property string nvmlPythonPath: "python3"
    readonly property string nvmlScriptPath: configDir + "/quickshell/scripts/nvidia_gpu_temp.py"
    readonly property string intelScriptPath: configDir + "/quickshell/scripts/intel_gpu_temp.py"

    Process {
        id: nvmlGpuProcess
        command: [nvmlPythonPath, nvmlScriptPath]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    try {
                        const data = JSON.parse(text.trim());
                        if (data.gpus && Array.isArray(data.gpus)) {
                            if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                                const gpuList = [];
                                for (const gpu of data.gpus) {
                                    gpuList.push({
                                        "driver": gpu.driver || "nvidia",
                                        "vendor": gpu.vendor || "NVIDIA",
                                        "displayName": gpu.displayName || gpu.name || "Unknown GPU",
                                        "fullName": gpu.fullName || gpu.name || "Unknown GPU",
                                        "pciId": gpu.pciId || "",
                                        "temperature": gpu.temperature || 0
                                    });
                                }
                                DgopService.availableGpus = gpuList;
                            } else {
                                const updatedGpus = DgopService.availableGpus.slice();
                                for (var i = 0; i < updatedGpus.length; i++) {
                                    const existingGpu = updatedGpus[i];
                                    let nvmlGpu = data.gpus.find(g => g.pciId === existingGpu.pciId);
                                    if (!nvmlGpu && i < data.gpus.length) {
                                        nvmlGpu = data.gpus[i];
                                    }
                                    if (nvmlGpu) {
                                        updatedGpus[i] = Object.assign({}, existingGpu, {
                                            "temperature": nvmlGpu.temperature || 0
                                        });
                                    }
                                }
                                DgopService.availableGpus = updatedGpus;
                            }
                        } else if (data.error) {
                        }
                    } catch (e) {
                    }
                }
            }
        }
    }

    Process {
        id: intelGpuProcess
        command: [nvmlPythonPath, intelScriptPath]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    try {
                        const data = JSON.parse(text.trim());
                        if (data.gpus && Array.isArray(data.gpus)) {
                            if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                                const gpuList = [];
                                for (const gpu of data.gpus) {
                                    gpuList.push({
                                        "driver": gpu.driver || "i915",
                                        "vendor": gpu.vendor || "Intel",
                                        "displayName": gpu.displayName || gpu.name || "Intel GPU",
                                        "fullName": gpu.fullName || gpu.name || "Intel GPU",
                                        "pciId": gpu.pciId || "",
                                        "temperature": gpu.temperature || 0
                                    });
                                }
                                DgopService.availableGpus = gpuList;
                            } else {
                                const updatedGpus = DgopService.availableGpus.slice();
                                for (const intelGpu of data.gpus) {
                                    let found = false;
                                    for (let i = 0; i < updatedGpus.length; i++) {
                                        const existingGpu = updatedGpus[i];
                                        if (existingGpu.pciId === intelGpu.pciId ||
                                            (existingGpu.vendor === "Intel" && intelGpu.vendor === "Intel")) {
                                            updatedGpus[i] = Object.assign({}, existingGpu, {
                                                "temperature": intelGpu.temperature || existingGpu.temperature || 0
                                            });
                                            found = true;
                                            break;
                                        }
                                    }
                                    if (!found) {
                                        updatedGpus.push({
                                            "driver": intelGpu.driver || "i915",
                                            "vendor": intelGpu.vendor || "Intel",
                                            "displayName": intelGpu.displayName || intelGpu.name || "Intel GPU",
                                            "fullName": intelGpu.fullName || intelGpu.name || "Intel GPU",
                                            "pciId": intelGpu.pciId || "",
                                            "temperature": intelGpu.temperature || 0
                                        });
                                    }
                                }
                                DgopService.availableGpus = updatedGpus;
                            }
                        }
                    } catch (e) {
                    }
                }
            }
        }
    }

    Timer {
        id: nvmlUpdateTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            nvmlGpuProcess.running = true;
            intelGpuProcess.running = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
        border.width: 1

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            EHIcon {
                name: "memory"
                size: SettingsData.desktopWidgetIconSize
                color: {
                    if (currentGpuTemperature > 85) {
                        return Theme.tempDanger;
                    }
                    if (currentGpuTemperature > 69) {
                        return Theme.tempWarning;
                    }
                    return Theme.surfaceText;
                }
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    text: "GPU"
                    font.pixelSize: SettingsData.desktopWidgetFontSize - 2
                    color: Theme.surfaceTextMedium
                    font.weight: Font.Medium
                }

                StyledText {
                    text: {
                        if (currentGpuTemperature === undefined || currentGpuTemperature === null || currentGpuTemperature < 0) {
                            return "--°";
                        }
                        return Math.round(currentGpuTemperature) + "°";
                    }
                    font.pixelSize: SettingsData.desktopWidgetFontSize + 2
                    font.weight: Font.Bold
                    color: {
                        if (currentGpuTemperature > 85) {
                            return Theme.tempDanger;
                        }
                        if (currentGpuTemperature > 69) {
                            return Theme.tempWarning;
                        }
                        return Theme.surfaceText;
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeAllCursor
            onPressed: {
                if (alwaysVisible) {
                }
            }
        }
    }
}
