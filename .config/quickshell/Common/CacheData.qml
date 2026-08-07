pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property int cacheConfigVersion: 1

    readonly property string _stateUrl: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)
    readonly property string _stateDir: Paths.strip(_stateUrl)

    property bool _loading: false

    property string wallpaperLastPath: ""
    property string profileLastPath: ""

    property var fileBrowserSettings: ({
            "wallpaper": {
                "lastPath": "",
                "viewMode": "grid",
                "sortBy": "name",
                "sortAscending": true,
                "iconSizeIndex": 1,
                "showSidebar": true
            },
            "profile": {
                "lastPath": "",
                "viewMode": "grid",
                "sortBy": "name",
                "sortAscending": true,
                "iconSizeIndex": 1,
                "showSidebar": true
            },
            "notepad_save": {
                "lastPath": "",
                "viewMode": "list",
                "sortBy": "name",
                "sortAscending": true,
                "iconSizeIndex": 1,
                "showSidebar": true
            },
            "notepad_load": {
                "lastPath": "",
                "viewMode": "list",
                "sortBy": "name",
                "sortAscending": true,
                "iconSizeIndex": 1,
                "showSidebar": true
            },
            "generic": {
                "lastPath": "",
                "viewMode": "list",
                "sortBy": "name",
                "sortAscending": true,
                "iconSizeIndex": 1,
                "showSidebar": true
            },
            "default": {
                "lastPath": "",
                "viewMode": "list",
                "sortBy": "name",
                "sortAscending": true,
                "iconSizeIndex": 1,
                "showSidebar": true
            }
        })

    Component.onCompleted: {
        loadCache();
    }

    function loadCache() {
        _loading = true;
        parseCache(cacheFile.text());
        _loading = false;
    }

    function parseCache(content) {
        _loading = true;
        try {
            if (content && content.trim()) {
                const cache = JSON.parse(content);

                wallpaperLastPath = cache.wallpaperLastPath !== undefined ? cache.wallpaperLastPath : "";
                profileLastPath = cache.profileLastPath !== undefined ? cache.profileLastPath : "";

                if (cache.fileBrowserSettings !== undefined) {
                    fileBrowserSettings = cache.fileBrowserSettings;
                } else if (cache.fileBrowserViewMode !== undefined) {
                    fileBrowserSettings = {
                        "wallpaper": {
                            "lastPath": cache.wallpaperLastPath || "",
                            "viewMode": cache.fileBrowserViewMode || "grid",
                            "sortBy": cache.fileBrowserSortBy || "name",
                            "sortAscending": cache.fileBrowserSortAscending !== undefined ? cache.fileBrowserSortAscending : true,
                            "iconSizeIndex": cache.fileBrowserIconSizeIndex !== undefined ? cache.fileBrowserIconSizeIndex : 1,
                            "showSidebar": cache.fileBrowserShowSidebar !== undefined ? cache.fileBrowserShowSidebar : true
                        },
                        "profile": {
                            "lastPath": cache.profileLastPath || "",
                            "viewMode": cache.fileBrowserViewMode || "grid",
                            "sortBy": cache.fileBrowserSortBy || "name",
                            "sortAscending": cache.fileBrowserSortAscending !== undefined ? cache.fileBrowserSortAscending : true,
                            "iconSizeIndex": cache.fileBrowserIconSizeIndex !== undefined ? cache.fileBrowserIconSizeIndex : 1,
                            "showSidebar": cache.fileBrowserShowSidebar !== undefined ? cache.fileBrowserShowSidebar : true
                        },
                        "default": {
                            "lastPath": "",
                            "viewMode": "list",
                            "sortBy": "name",
                            "sortAscending": true,
                            "iconSizeIndex": 1,
                            "showSidebar": true
                        }
                    };
                }

                if (cache.configVersion === undefined) {
                    migrateFromUndefinedToV1(cache);
                    cleanupUnusedKeys();
                    saveCache();
                }
            }
        } catch (e) {
            console.warn("CacheData: Failed to parse cache:", e.message);
        } finally {
            _loading = false;
        }
    }

    function saveCache() {
        if (_loading)
            return;
        cacheFile.setText(JSON.stringify({
            "wallpaperLastPath": wallpaperLastPath,
            "profileLastPath": profileLastPath,
            "fileBrowserSettings": fileBrowserSettings,
            "configVersion": cacheConfigVersion
        }, null, 2));
    }

    function migrateFromUndefinedToV1(cache) {
        console.info("CacheData: Migrating configuration from undefined to version 1");
    }

    function cleanupUnusedKeys() {
        const validKeys = ["wallpaperLastPath", "profileLastPath", "fileBrowserSettings", "configVersion"];

        try {
            const content = cacheFile.text();
            if (!content || !content.trim())
                return;
            const cache = JSON.parse(content);
            let needsSave = false;

            for (const key in cache) {
                if (!validKeys.includes(key)) {
                    console.log("CacheData: Removing unused key:", key);
                    delete cache[key];
                    needsSave = true;
                }
            }

            if (needsSave) {
                cacheFile.setText(JSON.stringify(cache, null, 2));
            }
        } catch (e) {
            console.warn("CacheData: Failed to cleanup unused keys:", e.message);
        }
    }

    FileView {
        id: cacheFile

        path: _stateDir + "/quickshell/cache.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        printErrors: false  // Suppress warnings for missing cache file on first run
        onLoaded: {
            parseCache(cacheFile.text());
        }
        onLoadFailed: error => {
            // Expected on first run - cache file will be created when needed
            // Don't log as it's not an error condition
        }
    }
}
