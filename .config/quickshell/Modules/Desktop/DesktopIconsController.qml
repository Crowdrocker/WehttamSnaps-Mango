import QtQuick
import Qt.labs.folderlistmodel
import QtCore
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Desktop

// Controller to manage desktop icon widgets
// Monitors the Desktop folder and creates/removes widget instances for .desktop and .ink files
Item {
    id: root

    // Desktop folder path
    readonly property string desktopPath: StandardPaths.writableLocation(StandardPaths.DesktopLocation)

    // Track which files we've created widgets for
    property var trackedFiles: ({})

    // Settings for icon widgets
    property int iconSize: 100

    Component.onCompleted: {
        console.log("[DesktopIconsController] Initialized, desktop path:", desktopPath);
    }

    // Use FolderListModel directly
    FolderListModel {
        id: folderModel
        folder: "file://" + root.desktopPath
        showDirsFirst: false
        showDotAndDotDot: false
        showHidden: false
        nameFilters: ["*.desktop", "*.ink"]
        showFiles: true
        showDirs: false

        onStatusChanged: {
            if (status === FolderListModel.Ready) {
                Qt.callLater(processDesktopFiles);
            }
        }
    }

    // Process files from the model
    function processDesktopFiles() {
        const files = [];
        for (let i = 0; i < folderModel.count; i++) {
            const filePath = folderModel.get(i, "filePath");
            const fileName = folderModel.get(i, "fileName");
            
            if (fileName && (fileName.endsWith(".desktop") || fileName.endsWith(".ink"))) {
                files.push({
                    path: filePath,
                    name: fileName
                });
            }
        }
        
        console.log("[DesktopIconsController] Found", files.length, "desktop/ink files");
        
        // Create a set of current file paths
        const currentPaths = {};
        files.forEach(f => currentPaths[f.path] = true);

        // Find files to remove (in tracked but not in current)
        for (const trackedPath in trackedFiles) {
            if (!currentPaths[trackedPath]) {
                console.log("[DesktopIconsController] Removing widget for:", trackedPath);
                removeDesktopIconWidget(trackedPath);
            }
        }

        // Find files to add
        files.forEach(file => {
            const isNew = !trackedFiles[file.path];
            if (isNew) {
                console.log("[DesktopIconsController] Adding widget for:", file.name);
                addDesktopIconWidget(file);
            }
        });
    }

    // Add a widget instance for a desktop/ink file
    function addDesktopIconWidget(file) {
        const filePath = file.path;
        const fileName = file.name;
        const isInk = fileName.endsWith(".ink");
        
        // Get target for .ink files (symlinks)
        let linkTarget = "";
        let desktopIcon = "application-x-desktop";
        let desktopName = fileName.replace(/\.desktop$/, "").replace(/\.ink$/, "");
        let desktopExec = "";

        if (isInk) {
            // Read symlink target
            try {
                const fileInfo = Quickshell.fileInfo(filePath);
                if (fileInfo && fileInfo.isSymLink) {
                    linkTarget = fileInfo.symLinkTarget || "";
                }
            } catch (e) {
                console.log("[DesktopIconsController] Error reading symlink:", e);
            }
        } else {
            // Parse .desktop file for icon and name
            const desktopEntry = DesktopEntries.lookup(filePath);
            if (desktopEntry) {
                desktopIcon = desktopEntry.icon || "application-x-desktop";
                desktopName = desktopEntry.name || desktopName;
                desktopExec = desktopEntry.command ? desktopEntry.command.join(" ") : "";
            }
        }

        // Generate unique instance ID
        const instanceId = "desktopIcon_" + fileName.replace(/[^a-zA-Z0-9]/g, "_");

        // Create widget instance data
        const instanceData = {
            id: instanceId,
            widgetType: "desktopIcon",
            enabled: true,
            config: {
                desktopFilePath: filePath,
                desktopFileName: fileName,
                desktopName: desktopName,
                desktopIcon: desktopIcon,
                desktopExec: desktopExec,
                desktopIsLink: isInk,
                linkTarget: linkTarget,
                width: iconSize,
                height: iconSize,
                displayPreferences: ["all"]
            },
            positions: { "primary": { x: 100, y: 100 } }
        };

        console.log("[DesktopIconsController] Creating widget instance:", instanceId);
        trackedFiles[filePath] = instanceId;
        
        // Add to SettingsData desktop widget instances
        addWidgetInstance(instanceData);
    }

    // Remove a widget instance
    function removeDesktopIconWidget(filePath) {
        const instanceId = trackedFiles[filePath];
        if (instanceId) {
            console.log("[DesktopIconsController] Removing widget instance:", instanceId);
            removeWidgetInstance(instanceId);
            delete trackedFiles[filePath];
        }
    }

    // Add widget instance to SettingsData
    function addWidgetInstance(instanceData) {
        const instances = SettingsData.desktopWidgetInstances || [];
        
        // Check if already exists
        const existingIndex = instances.findIndex(inst => inst.id === instanceData.id);
        if (existingIndex >= 0) {
            instances[existingIndex] = instanceData;
        } else {
            instances.push(instanceData);
        }
        
        SettingsData.desktopWidgetInstances = instances;
    }

    // Remove widget instance from SettingsData
    function removeWidgetInstance(instanceId) {
        let instances = SettingsData.desktopWidgetInstances || [];
        instances = instances.filter(inst => inst.id !== instanceId);
        SettingsData.desktopWidgetInstances = instances;
    }

    // Refresh - called to rescan the desktop folder
    function refresh() {
        console.log("[DesktopIconsController] Refreshing...");
        folderModel.folder = "file://" + desktopPath;
    }
}
