import QtQuick
import QtCore
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string instanceId: ""
    property var instanceData: null
    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    property real widgetWidth: 512
    property real widgetHeight: 512
    property real defaultWidth: 512
    property real defaultHeight: 512
    property real minWidth: 384
    property real minHeight: 384

    property real widgetOpacity: isInstance ? (cfg?.transparency ?? 0.8) : 0.8
    
    property real scaleFactor: Math.min(widgetWidth / 512, widgetHeight / 512)
    property real baseFontSize: 16
    property real scaledFontSize: baseFontSize * scaleFactor
    property real baseSpacing: 16
    property real scaledSpacing: baseSpacing * scaleFactor
    property real basePadding: 20
    property real scaledPadding: basePadding * scaleFactor
    
    property real contentHeight: widgetHeight
    
    property real currentCpuTemperature: DgopService.cpuTemperature || 0
    property real currentGpuTemperature: (DgopService.availableGpus && DgopService.availableGpus.length > 0) ? (DgopService.availableGpus[0].temperature || -1) : -1
    property real currentGpuMemoryUsed: (DgopService.availableGpus && DgopService.availableGpus.length > 0) ? (DgopService.availableGpus[0].memoryUsedMB || 0) : 0
    property real currentGpuMemoryTotal: (DgopService.availableGpus && DgopService.availableGpus.length > 0) ? (DgopService.availableGpus[0].memoryTotalMB || 0) : 0
    property real currentCpuUsage: DgopService.cpuUsage || 0
    property real currentMemoryUsage: DgopService.memoryUsage || 0
    property real currentMemoryTotalMB: DgopService.totalMemoryMB || 0
    property real currentMemoryUsedMB: DgopService.usedMemoryMB || 0
    property real currentNetworkDownloadSpeed: DgopService.networkRxRate || 0
    property real currentNetworkUploadSpeed: DgopService.networkTxRate || 0
    
    property var cpuUsageHistory: []
    property var memoryUsageHistory: []
    property var gpuMemoryHistory: []
    property var networkHistory: []
    property int maxHistoryPoints: 12

    Component.onCompleted: {
        DgopService.addRef(["cpu", "memory", "gpu", "network"]);
        
        // Delay starting GPU monitoring to ensure processes are initialized
        Qt.callLater(() => {
            startNvmlMonitoring();
        });
        
        for (var i = 0; i < 5; i++) {
            cpuUsageHistory.push(0);
            memoryUsageHistory.push(0);
            gpuMemoryHistory.push(0);
            networkHistory.push(0);
        }
        
        Qt.callLater(() => {
            currentMemoryUsage = DgopService.memoryUsage || 0;
            currentMemoryTotalMB = DgopService.totalMemoryMB || 0;
            currentMemoryUsedMB = DgopService.usedMemoryMB || 0;
        });
    }

    Component.onDestruction: {
        DgopService.removeRef(["cpu", "memory", "gpu", "network"]);
    }

    Connections {
        target: DgopService
        function onCpuUsageChanged() {
            currentCpuUsage = DgopService.cpuUsage || 0;
        }
        function onCpuTemperatureChanged() {
            currentCpuTemperature = DgopService.cpuTemperature || 0;
        }
        function onMemoryUsageChanged() {
            currentMemoryUsage = DgopService.memoryUsage || 0;
            currentMemoryTotalMB = DgopService.totalMemoryMB || 0;
            currentMemoryUsedMB = DgopService.usedMemoryMB || 0;
        }
        function onTotalMemoryMBChanged() {
            currentMemoryTotalMB = DgopService.totalMemoryMB || 0;
        }
        function onUsedMemoryMBChanged() {
            currentMemoryUsedMB = DgopService.usedMemoryMB || 0;
        }
        function onNetworkRxRateChanged() {
            currentNetworkDownloadSpeed = DgopService.networkRxRate || 0;
        }
        function onNetworkTxRateChanged() {
            currentNetworkUploadSpeed = DgopService.networkTxRate || 0;
        }
        function onAvailableGpusChanged() {
            currentGpuTemperature = (DgopService.availableGpus && DgopService.availableGpus.length > 0) ? (DgopService.availableGpus[0].temperature || -1) : -1;
        }
    }

    function getCpuTemperature() {
        return DgopService.cpuTemperature || 0;
    }

    function getGpuTemperature() {
        if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
            return -1;
        }
        
        if (SettingsData.desktopGpuSelection === "auto") {
            const gpu = DgopService.availableGpus[0];
            return gpu.temperature !== undefined ? gpu.temperature : -1;
        }
        
        const options = SettingsData.getGpuDropdownOptions();
        const selectedIndex = options.indexOf(SettingsData.desktopGpuSelection);
        
        if (selectedIndex > 0 && selectedIndex <= DgopService.availableGpus.length) {
            const gpuIndex = selectedIndex - 1;
            const gpu = DgopService.availableGpus[gpuIndex];
            return gpu.temperature || -1;
        }
        
        return -1;
    }
    
    function getShortCpuName() {
        if (SettingsData.desktopSystemMonitorCustomCpuName && SettingsData.desktopSystemMonitorCustomCpuName.trim() !== "") {
            return SettingsData.desktopSystemMonitorCustomCpuName.trim();
        }

        const fullName = DgopService.cpuModel || "CPU";
        
        // Check if it's an Intel CPU
        const isIntel = /^Intel/i.test(fullName);
        
        let shortName = fullName
            // Remove vendor prefixes
            .replace(/^AMD\s+/i, "")
            .replace(/^Intel\s*\(R\)\s*/i, "")
            .replace(/^Intel\s+/i, "")
            // Remove trademark suffixes
            .replace(/\s*\(R\)/g, "")
            .replace(/\s*\(TM\)/g, "")
            // Remove trailing processor/CPU labels
            .replace(/\s+Processor$/i, "")
            .replace(/\s+CPU$/i, "")
            // Remove frequency info (e.g., "@ 3.60GHz")
            .replace(/\s+@\s+[\d.]+GHz.*$/i, "")
            .replace(/\s+@.*$/i, "")
            // Remove core count suffixes (e.g., "8-Core", "6 Core", "4-Core Processor")
            // But preserve "Core i7" type names for Intel
            .replace(/\s+\d+\s*-\s*Core.*$/i, "")
            .replace(/\s+\d+\s*Core.*$/i, "")
            // Remove graphics suffixes
            .replace(/\s+Radeon\s+Graphics.*$/i, "")
            .replace(/\s+Graphics.*$/i, "")
            .replace(/\s+with.*$/i, "")
            .trim();
        
        // For Intel CPUs, if we removed too much and it's empty or just "Core", 
        // try to extract the model name more carefully
        if (isIntel && (!shortName || shortName === "Core" || shortName.length < 3)) {
            // Try to match Intel Core series (e.g., "Core i7-9700K", "Core i5-12400")
            const coreMatch = fullName.match(/Core\s+(i[3579]|Xeon|Pentium|Celeron)[\s-]?([\w-]+)?/i);
            if (coreMatch) {
                const series = coreMatch[1];
                const model = coreMatch[2] || "";
                shortName = "Core " + series + (model ? "-" + model : "");
            } else {
                // Fallback: try to get anything after "Intel" that looks like a model
                const modelMatch = fullName.replace(/^Intel\s*\(?R\)?\s*/i, "").match(/^([A-Za-z0-9\s-]+?)(?:\s+\(|@|\s+CPU|\s+Processor|$)/);
                if (modelMatch) {
                    shortName = modelMatch[1].trim();
                }
            }
        }
        
        if (!shortName || shortName.length < 2) return fullName;
        
        return shortName;
    }
    
    function getShortGpuName() {
        if (SettingsData.desktopSystemMonitorCustomGpuName && SettingsData.desktopSystemMonitorCustomGpuName.trim() !== "") {
            return SettingsData.desktopSystemMonitorCustomGpuName.trim();
        }

        if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
            return "GPU";
        }

        const gpu = DgopService.availableGpus[0];
        const fullName = gpu.displayName || "GPU";

        const isRadeon = /radeon/i.test(fullName) || /amd/i.test(fullName) || gpu.vendor === "AMD";

        let shortName = fullName;

        if (isRadeon) {
            shortName = fullName
                .replace(/^AMD\s+Radeon\s+/i, "")
                .replace(/^Radeon\s+/i, "")
                .replace(/^AMD\s+/i, "")
                .replace(/\s*\/\s*.*/i, "")
                .replace(/\s*\([^)]*\)/g, "")
                .replace(/\s+/g, " ")
                .trim();

            const rxMatch = shortName.match(/(?:Radeon\s+)?(?:RX\s+)?(\d{2,4}\s*\w+(?:\s*\w+)*)/i);
            if (rxMatch) {
                const modelNumber = rxMatch[1].replace(/\s+/g, "").toUpperCase();
                shortName = "RX " + modelNumber;
            }
        } else {
            shortName = fullName
                .replace(/^NVIDIA\s+GeForce\s+/i, "")
                .replace(/^GeForce\s+/i, "")
                .replace(/^Intel\s+Arc\s+/i, "")
                .replace(/^Intel\s+UHD\s+/i, "")
                .replace(/^Intel\s+HD\s+/i, "")
                .replace(/^NVIDIA\s+/i, "")
                .replace(/^Intel\s+/i, "")
                .replace(/\s*\/\s*Max-Q.*$/i, "")
                .trim();
        }
        
        if (!shortName) return fullName;
        
        return shortName;
    }

    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
    readonly property string nvmlPythonPath: "python3"
    readonly property string nvmlScriptPath: configDir + "/quickshell/scripts/nvidia_gpu_temp.py"
    readonly property string amdScriptPath: configDir + "/quickshell/scripts/amd_gpu_temp.py"
    readonly property string intelScriptPath: configDir + "/quickshell/scripts/intel_gpu_temp.py"

    function startNvmlMonitoring() {
        nvmlGpuProcess.running = true;
        amdGpuProcess.running = true;
        intelGpuProcess.running = true;
    }


    Process {
        id: nvmlGpuProcess
        command: [nvmlPythonPath, nvmlScriptPath]
        running: false
        onExited: exitCode => {
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
                                        "temperature": gpu.temperature || 0,
                                        "memoryUsed": gpu.memoryUsed || 0,
                                        "memoryTotal": gpu.memoryTotal || 0,
                                        "memoryUsedMB": gpu.memoryUsedMB || 0,
                                        "memoryTotalMB": gpu.memoryTotalMB || 0
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
                                            "temperature": nvmlGpu.temperature || 0,
                                            "memoryUsed": nvmlGpu.memoryUsed || 0,
                                            "memoryTotal": nvmlGpu.memoryTotal || 0,
                                            "memoryUsedMB": nvmlGpu.memoryUsedMB || 0,
                                            "memoryTotalMB": nvmlGpu.memoryTotalMB || 0
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

    Process {
        id: amdGpuProcess
        command: [nvmlPythonPath, amdScriptPath]
        running: false
        onExited: exitCode => {
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
                                        "driver": gpu.driver || "amdgpu",
                                        "vendor": gpu.vendor || "AMD",
                                        "displayName": gpu.displayName || gpu.name || "AMD GPU",
                                        "fullName": gpu.fullName || gpu.name || "AMD GPU",
                                        "pciId": gpu.pciId || "",
                                        "temperature": gpu.temperature || 0,
                                        "memoryUsed": gpu.memoryUsed || 0,
                                        "memoryTotal": gpu.memoryTotal || 0,
                                        "memoryUsedMB": gpu.memoryUsedMB || 0,
                                        "memoryTotalMB": gpu.memoryTotalMB || 0
                                    });
                                }
                                DgopService.availableGpus = gpuList;
                            } else {
                                const updatedGpus = DgopService.availableGpus.slice();
                                for (const amdGpu of data.gpus) {
                                    let found = false;
                                    for (let i = 0; i < updatedGpus.length; i++) {
                                        const existingGpu = updatedGpus[i];
                                        if (existingGpu.pciId === amdGpu.pciId ||
                                            (existingGpu.vendor === "AMD" && amdGpu.vendor === "AMD")) {
                                            updatedGpus[i] = Object.assign({}, existingGpu, {
                                                "temperature": amdGpu.temperature || existingGpu.temperature || 0,
                                                "memoryUsed": amdGpu.memoryUsed || existingGpu.memoryUsed || 0,
                                                "memoryTotal": amdGpu.memoryTotal || existingGpu.memoryTotal || 0,
                                                "memoryUsedMB": amdGpu.memoryUsedMB || existingGpu.memoryUsedMB || 0,
                                                "memoryTotalMB": amdGpu.memoryTotalMB || existingGpu.memoryTotalMB || 0
                                            });
                                            found = true;
                                            break;
                                        }
                                    }
                                    if (!found) {
                                        updatedGpus.push({
                                            "driver": amdGpu.driver || "amdgpu",
                                            "vendor": amdGpu.vendor || "AMD",
                                            "displayName": amdGpu.displayName || amdGpu.name || "AMD GPU",
                                            "fullName": amdGpu.fullName || amdGpu.name || "AMD GPU",
                                            "pciId": amdGpu.pciId || "",
                                            "temperature": amdGpu.temperature || 0,
                                            "memoryUsed": amdGpu.memoryUsed || 0,
                                            "memoryTotal": amdGpu.memoryTotal || 0,
                                            "memoryUsedMB": amdGpu.memoryUsedMB || 0,
                                            "memoryTotalMB": amdGpu.memoryTotalMB || 0
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

    Process {
        id: intelGpuProcess
        command: [nvmlPythonPath, intelScriptPath]
        running: false
        onExited: exitCode => {
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
                                        "temperature": gpu.temperature || 0,
                                        "memoryUsed": gpu.memoryUsed || 0,
                                        "memoryTotal": gpu.memoryTotal || 0,
                                        "memoryUsedMB": gpu.memoryUsedMB || 0,
                                        "memoryTotalMB": gpu.memoryTotalMB || 0
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
                                                "temperature": intelGpu.temperature || existingGpu.temperature || 0,
                                                "memoryUsed": intelGpu.memoryUsed || existingGpu.memoryUsed || 0,
                                                "memoryTotal": intelGpu.memoryTotal || existingGpu.memoryTotal || 0,
                                                "memoryUsedMB": intelGpu.memoryUsedMB || existingGpu.memoryUsedMB || 0,
                                                "memoryTotalMB": intelGpu.memoryTotalMB || existingGpu.memoryTotalMB || 0
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
                                            "temperature": intelGpu.temperature || 0,
                                            "memoryUsed": intelGpu.memoryUsed || 0,
                                            "memoryTotal": intelGpu.memoryTotal || 0,
                                            "memoryUsedMB": intelGpu.memoryUsedMB || 0,
                                            "memoryTotalMB": intelGpu.memoryTotalMB || 0
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
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // Run all GPU processes to detect any GPU type
            nvmlGpuProcess.running = true;
            amdGpuProcess.running = true;
            intelGpuProcess.running = true;
        }
    }

    property bool pendingGraphUpdate: false
    
    Timer {
        id: graphUpdateTimer
        interval: 2000
        running: root.visible
        repeat: true
        onTriggered: {
            cpuUsageHistory.push(currentCpuUsage);
            if (cpuUsageHistory.length > maxHistoryPoints) {
                cpuUsageHistory.shift();
            }
            
            const memUsage = DgopService.memoryUsage || 0
            memoryUsageHistory.push(memUsage);
            if (memoryUsageHistory.length > maxHistoryPoints) {
                memoryUsageHistory.shift();
            }
            
            const gpuMemoryPercent = currentGpuMemoryTotal > 0 ? (currentGpuMemoryUsed / currentGpuMemoryTotal) * 100 : 0;
            gpuMemoryHistory.push(gpuMemoryPercent);
            if (gpuMemoryHistory.length > maxHistoryPoints) {
                gpuMemoryHistory.shift();
            }
            
            const totalNetworkSpeed = (currentNetworkDownloadSpeed + currentNetworkUploadSpeed) / (1024 * 1024);
            networkHistory.push(totalNetworkSpeed);
            if (networkHistory.length > maxHistoryPoints) {
                networkHistory.shift();
            }
            
            // Batch all graph updates together
            if (!pendingGraphUpdate) {
                pendingGraphUpdate = true;
                Qt.callLater(() => {
                    cpuUsageHistoryChanged();
                    memoryUsageHistoryChanged();
                    gpuMemoryHistoryChanged();
                    networkHistoryChanged();
                    pendingGraphUpdate = false;
                });
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, widgetOpacity)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, SettingsData.desktopWidgetBorderOpacity)
        border.width: SettingsData.desktopWidgetBorderThickness
        opacity: widgetOpacity
        antialiasing: true

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, widgetOpacity - 0.05) }
            GradientStop { position: 1.0; color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, widgetOpacity) }
        }


        Column {
            anchors.fill: parent
            anchors.margins: scaledPadding
            spacing: scaledSpacing

            Grid {
                width: parent.width
                height: parent.height
                columns: 2
                rows: 2
                spacing: 16 * scaleFactor
                
                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: (parent.height - parent.spacing) / 2
                    radius: Theme.cornerRadius * 0.6
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 1
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1) 
                        border.width: 1
                    }
                    
                    Column {
                        id: cpuContent
                        anchors.fill: parent
                        anchors.margins: 12 * scaleFactor
                        spacing: 8 * scaleFactor
                        
                        StyledText {
                            text: getShortCpuName()
                            font.pixelSize: 16 * scaleFactor
                            color: Theme.surfaceTextMedium
                            font.weight: Font.Bold
                            anchors.horizontalCenter: parent.horizontalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        
                        Rectangle {
                            width: parent.width
                            height: 100 * scaleFactor
                            radius: Theme.cornerRadius * 0.3
                            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.8)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            border.width: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            
                            Canvas {
                                id: cpuGraph
                                anchors.fill: parent
                                anchors.margins: 2
                                renderTarget: Canvas.FramebufferObject
                                
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    
                                    if (cpuUsageHistory.length < 2) return;
                                    
                                    ctx.strokeStyle = currentCpuUsage > 90 ? Theme.tempDanger : (currentCpuUsage > 70 ? Theme.tempWarning : Theme.primary);
                                    ctx.lineWidth = 2;
                                    ctx.beginPath();
                                    
                                    var stepX = width / Math.max(1, cpuUsageHistory.length - 1);
                                    var maxValue = 100;
                                    var len = cpuUsageHistory.length;
                                    
                                    for (var i = 0; i < len; i++) {
                                        var x = i * stepX;
                                        var y = height - (cpuUsageHistory[i] / maxValue) * height;
                                        
                                        if (i === 0) {
                                            ctx.moveTo(x, y);
                                        } else {
                                            ctx.lineTo(x, y);
                                        }
                                    }
                                    
                                    ctx.stroke();
                                }
                                
                                onWidthChanged: if (width > 0) requestPaint();
                                onHeightChanged: if (height > 0) requestPaint();
                            }
                            
                            Connections {
                                target: root
                                function onCpuUsageHistoryChanged() {
                                    cpuGraph.requestPaint();
                                }
                            }
                        }
                        
                        Item {
                            height: 8 * scaleFactor
                        }
                        
                        Item {
                            width: parent.width - 16 * scaleFactor
                            height: 50 * scaleFactor
                            
                            Column {
                                spacing: 2 * scaleFactor
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                
                                StyledText {
                                    text: "TEMP"
                                    font.pixelSize: 8 * scaleFactor
                                    color: Theme.surfaceTextMedium
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.5
                                }
                                
                                StyledText {
                                    text: currentCpuTemperature > 0 ? Math.round(currentCpuTemperature) + "°C" : "--°C"
                                    font.pixelSize: 24 * scaleFactor
                                    font.weight: Font.Bold
                                    color: {
                                        if (currentCpuTemperature > 80) return Theme.tempDanger
                                        if (currentCpuTemperature > 65) return Theme.tempWarning
                                        return Theme.surfaceText
                                    }
                                }
                            }
                            
                            Column {
                                spacing: 2 * scaleFactor
                                anchors.right: parent.right
                                anchors.rightMargin: -9 * scaleFactor
                                anchors.verticalCenter: parent.verticalCenter
                                
                                StyledText {
                                    text: "USAGE"
                                    font.pixelSize: 8 * scaleFactor
                                    color: Theme.surfaceTextMedium
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.5
                                    anchors.right: parent.right
                                }
                                
                                StyledText {
                                    text: Math.round(currentCpuUsage) + "%"
                                    font.pixelSize: 24 * scaleFactor
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    anchors.right: parent.right
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: (parent.height - parent.spacing) / 2
                    radius: Theme.cornerRadius * 0.6
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 1
                    visible: DgopService.availableGpus && DgopService.availableGpus.length > 0
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                        border.width: 1
                    }
                    
                    Column {
                        id: gpuContent
                        anchors.fill: parent
                        anchors.margins: 12 * scaleFactor
                        spacing: 8 * scaleFactor
                        
                        StyledText {
                            text: getShortGpuName()
                            font.pixelSize: 16 * scaleFactor
                            color: Theme.surfaceTextMedium
                            font.weight: Font.Bold
                            anchors.horizontalCenter: parent.horizontalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        
                        Rectangle {
                            width: parent.width
                            height: 100 * scaleFactor
                            radius: Theme.cornerRadius * 0.3
                            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.8)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            border.width: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            
                            Canvas {
                                id: gpuGraph
                                anchors.fill: parent
                                anchors.margins: 2
                                renderTarget: Canvas.FramebufferObject
                                
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    
                                    if (gpuMemoryHistory.length < 2) return;
                                    
                                    ctx.strokeStyle = Theme.secondary;
                                    ctx.lineWidth = 2;
                                    ctx.beginPath();
                                    
                                    var stepX = width / Math.max(1, gpuMemoryHistory.length - 1);
                                    var maxValue = 100;
                                    var len = gpuMemoryHistory.length;
                                    
                                    for (var i = 0; i < len; i++) {
                                        var x = i * stepX;
                                        var y = height - (gpuMemoryHistory[i] / maxValue) * height;
                                        
                                        if (i === 0) {
                                            ctx.moveTo(x, y);
                                        } else {
                                            ctx.lineTo(x, y);
                                        }
                                    }
                                    
                                    ctx.stroke();
                                }
                                
                                onWidthChanged: if (width > 0) requestPaint();
                                onHeightChanged: if (height > 0) requestPaint();
                            }
                            
                            Connections {
                                target: root
                                function onGpuMemoryHistoryChanged() {
                                    gpuGraph.requestPaint();
                                }
                            }
                        }
                        
                        Item {
                            height: 8 * scaleFactor
                        }
                        
                        Item {
                            width: parent.width - 16 * scaleFactor
                            height: 50 * scaleFactor
                            
                            Column {
                                spacing: 2 * scaleFactor
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                
                                StyledText {
                                    text: "TEMP"
                                    font.pixelSize: 8 * scaleFactor
                                    color: Theme.surfaceTextMedium
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.5
                                }
                                
                                StyledText {
                                    text: currentGpuTemperature > 0 ? Math.round(currentGpuTemperature) + "°C" : "--°C"
                                    font.pixelSize: 20 * scaleFactor
                                    font.weight: Font.Bold
                                    color: {
                                        if (currentGpuTemperature > 85) return Theme.tempDanger
                                        if (currentGpuTemperature > 70) return Theme.tempWarning
                                        return Theme.surfaceText
                                    }
                                }
                            }
                            
                            Column {
                                spacing: 2 * scaleFactor
                                anchors.right: parent.right
                                anchors.rightMargin: -9 * scaleFactor
                                anchors.verticalCenter: parent.verticalCenter
                                
                                StyledText {
                                    text: "VRAM"
                                    font.pixelSize: 8 * scaleFactor
                                    color: Theme.surfaceTextMedium
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.5
                                    anchors.right: parent.right
                                }
                                
                                StyledText {
                                    text: {
                                        if (currentGpuMemoryUsed > 0) {
                                            const usedGB = (currentGpuMemoryUsed / 1024).toFixed(1)
                                            return usedGB + "GB"
                                        }
                                        return currentGpuTemperature > 0 ? "Active" : "Offline"
                                    }
                                    font.pixelSize: 20 * scaleFactor
                                    font.weight: Font.Bold
                                    color: currentGpuTemperature > 0 ? Theme.surfaceText : Theme.surfaceTextMedium
                                    anchors.right: parent.right
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: (parent.height - parent.spacing) / 2
                    radius: Theme.cornerRadius * 0.6
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 1
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                        border.width: 1
                    }
                    
                    Column {
                        id: ramContent
                        anchors.fill: parent
                        anchors.margins: 12 * scaleFactor
                        spacing: 8 * scaleFactor
                        
                        StyledText {
                            text: "RAM"
                            font.pixelSize: 16 * scaleFactor
                            color: Theme.surfaceTextMedium
                            font.weight: Font.Bold
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Rectangle {
                            width: parent.width
                            height: 100 * scaleFactor
                            radius: Theme.cornerRadius * 0.3
                            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.8)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            border.width: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            
                            Canvas {
                                id: ramGraph
                                anchors.fill: parent
                                anchors.margins: 2
                                renderTarget: Canvas.FramebufferObject
                                
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    
                                    if (memoryUsageHistory.length < 2) return;
                                    
                                    const usage = DgopService.memoryUsage || 0
                                    ctx.strokeStyle = usage > 90 ? Theme.tempDanger : (usage > 75 ? Theme.tempWarning : Theme.primary);
                                    ctx.lineWidth = 2;
                                    ctx.beginPath();
                                    
                                    var stepX = width / Math.max(1, memoryUsageHistory.length - 1);
                                    var maxValue = 100;
                                    var len = memoryUsageHistory.length;
                                    
                                    for (var i = 0; i < len; i++) {
                                        var x = i * stepX;
                                        var y = height - (memoryUsageHistory[i] / maxValue) * height;
                                        
                                        if (i === 0) {
                                            ctx.moveTo(x, y);
                                        } else {
                                            ctx.lineTo(x, y);
                                        }
                                    }
                                    
                                    ctx.stroke();
                                }
                                
                                onWidthChanged: if (width > 0) requestPaint();
                                onHeightChanged: if (height > 0) requestPaint();
                            }
                            
                            Connections {
                                target: root
                                function onMemoryUsageHistoryChanged() {
                                    ramGraph.requestPaint();
                                }
                            }
                        }
                        
                        Item {
                            height: 8 * scaleFactor
                        }
                        
                        Item {
                            width: parent.width - 16 * scaleFactor
                            height: 50 * scaleFactor
                            
                            Column {
                                spacing: 2 * scaleFactor
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                
                                StyledText {
                                    text: "USAGE"
                                    font.pixelSize: 8 * scaleFactor
                                    color: Theme.surfaceTextMedium
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.5
                                }
                                
                                StyledText {
                                    text: {
                                        const usage = DgopService.memoryUsage || 0
                                        if (usage > 0) {
                                            return Math.round(usage) + "%"
                                        }
                                        return "--%"
                                    }
                                    font.pixelSize: 24 * scaleFactor
                                    font.weight: Font.Bold
                                    color: {
                                        const usage = DgopService.memoryUsage || 0
                                        if (usage > 90) return Theme.tempDanger
                                        if (usage > 75) return Theme.tempWarning
                                        return Theme.surfaceText
                                    }
                                }
                            }
                            
                            Column {
                                spacing: 2 * scaleFactor
                                anchors.right: parent.right
                                anchors.rightMargin: -9 * scaleFactor
                                anchors.verticalCenter: parent.verticalCenter
                                
                                StyledText {
                                    text: "TOTAL"
                                    font.pixelSize: 8 * scaleFactor
                                    color: Theme.surfaceTextMedium
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.5
                                    anchors.right: parent.right
                                }
                                
                                StyledText {
                                    text: {
                                        const usedMB = DgopService.usedMemoryMB || 0
                                        const totalMB = DgopService.totalMemoryMB || 0
                                        
                                        if (totalMB > 0) {
                                            const usedGB = (usedMB / 1024).toFixed(1)
                                            const totalGB = (totalMB / 1024).toFixed(1)
                                            return usedGB + "/" + totalGB + "GB"
                                        }
                                        return "--/--GB"
                                    }
                                    font.pixelSize: 18 * scaleFactor
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    anchors.right: parent.right
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: (parent.height - parent.spacing) / 2
                    radius: Theme.cornerRadius * 0.6
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    border.width: 1
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                        border.width: 1
                    }
                    
                    Column {
                        id: networkContent
                        anchors.fill: parent
                        anchors.margins: 12 * scaleFactor
                        spacing: 8 * scaleFactor
                        
                        StyledText {
                            text: "NETWORK"
                            font.pixelSize: 16 * scaleFactor
                            color: Theme.surfaceTextMedium
                            font.weight: Font.Bold
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Rectangle {
                            width: parent.width
                            height: 100 * scaleFactor
                            radius: Theme.cornerRadius * 0.3
                            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.8)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            border.width: 1
                            anchors.horizontalCenter: parent.horizontalCenter
                            
                            Canvas {
                                id: networkGraph
                                anchors.fill: parent
                                anchors.margins: 2
                                renderTarget: Canvas.FramebufferObject
                                
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    
                                    if (networkHistory.length < 2) return;
                                    
                                    ctx.strokeStyle = Theme.primary;
                                    ctx.lineWidth = 2;
                                    ctx.beginPath();
                                    
                                    var stepX = width / Math.max(1, networkHistory.length - 1);
                                    var maxValue = 10;
                                    var len = networkHistory.length;
                                    
                                    for (var i = 0; i < len; i++) {
                                        var x = i * stepX;
                                        var y = height - Math.min((networkHistory[i] / maxValue) * height, height);
                                        
                                        if (i === 0) {
                                            ctx.moveTo(x, y);
                                        } else {
                                            ctx.lineTo(x, y);
                                        }
                                    }
                                    
                                    ctx.stroke();
                                }
                                
                                onWidthChanged: if (width > 0) requestPaint();
                                onHeightChanged: if (height > 0) requestPaint();
                            }
                            
                            Connections {
                                target: root
                                function onNetworkHistoryChanged() {
                                    networkGraph.requestPaint();
                                }
                            }
                        }
                        
                        Item {
                            height: 8 * scaleFactor
                        }
                        
                        Item {
                            width: parent.width - 16 * scaleFactor
                            height: 50 * scaleFactor
                            
                            Column {
                                spacing: 2 * scaleFactor
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                
                                StyledText {
                                    text: "DOWN"
                                    font.pixelSize: 8 * scaleFactor
                                    color: Theme.surfaceTextMedium
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.5
                                }
                                
                                Row {
                                    spacing: 2 * scaleFactor
                                    
                                    StyledText {
                                        text: {
                                            const downloadSpeed = currentNetworkDownloadSpeed || 0
                                            if (downloadSpeed === 0) return "0"
                                            
                                            if (downloadSpeed >= 1024 * 1024) {
                                                return (downloadSpeed / 1024 / 1024).toFixed(1)
                                            } else {
                                                return (downloadSpeed / 1024).toFixed(1)
                                            }
                                        }
                                        font.pixelSize: 20 * scaleFactor
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                    }
                                    
                                    StyledText {
                                        text: {
                                            const downloadSpeed = currentNetworkDownloadSpeed || 0
                                            if (downloadSpeed >= 1024 * 1024) {
                                                return "MB/s"
                                            } else {
                                                return "KB/s"
                                            }
                                        }
                                        font.pixelSize: 12 * scaleFactor
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                            
                            Column {
                                spacing: 2 * scaleFactor
                                anchors.right: parent.right
                                anchors.rightMargin: -9 * scaleFactor
                                anchors.verticalCenter: parent.verticalCenter
                                
                                StyledText {
                                    text: "UP"
                                    font.pixelSize: 8 * scaleFactor
                                    color: Theme.surfaceTextMedium
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.5
                                    anchors.right: parent.right
                                }
                                
                                Row {
                                    spacing: 2 * scaleFactor
                                    anchors.right: parent.right
                                    
                                    StyledText {
                                        text: {
                                            const uploadSpeed = currentNetworkUploadSpeed || 0
                                            if (uploadSpeed === 0) return "0"
                                            
                                            if (uploadSpeed >= 1024 * 1024) {
                                                return (uploadSpeed / 1024 / 1024).toFixed(1)
                                            } else {
                                                return (uploadSpeed / 1024).toFixed(1)
                                            }
                                        }
                                        font.pixelSize: 20 * scaleFactor
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                    }
                                    
                                    StyledText {
                                        text: {
                                            const uploadSpeed = currentNetworkUploadSpeed || 0
                                            if (uploadSpeed >= 1024 * 1024) {
                                                return "MB/s"
                                            } else {
                                                return "KB/s"
                                            }
                                        }
                                        font.pixelSize: 12 * scaleFactor
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
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
