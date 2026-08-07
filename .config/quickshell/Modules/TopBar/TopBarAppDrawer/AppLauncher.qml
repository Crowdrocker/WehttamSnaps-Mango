import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string searchQuery: ""
    property string selectedCategory: "All"
    property string viewMode: "list"
    property int selectedIndex: 0
    property int maxResults: 50
    property int gridColumns: 4
    property bool debounceSearch: true
    // Increased debounce: 80 ms is imperceptible for search but halves update rate at 120 Hz
    property int debounceInterval: 80
    property bool keyboardNavigationActive: false
    property bool suppressUpdatesWhileLaunching: false

    // ── dirty-flag: only rebuild when the drawer is actually visible ──────────
    property bool _pendingRebuild: false
    property bool drawerVisible: false      // set by AppDrawerPopout

    readonly property var categories: {
        const allCategories = AppSearchService.getAllCategories().filter(
            cat => cat !== "Education" && cat !== "Science"
        )
        return ["All"].concat(allCategories.filter(cat => cat !== "All"))
    }
    readonly property var categoryIcons: categories.map(
        category => AppSearchService.getCategoryIcon(category)
    )
    // Cache usage ranking to avoid redundant model rebuilds when value is unchanged
    property var appUsageRanking: AppUsageHistoryData.appUsageRanking || {}
    property alias model: filteredModel
    property var _watchApplications: AppSearchService.applications

    signal appLaunched(var app)
    signal categorySelected(string category)
    signal viewModeSelected(string mode)

    // ── Core filter/sort logic ────────────────────────────────────────────────
    function updateFilteredModel() {
        if (suppressUpdatesWhileLaunching) {
            suppressUpdatesWhileLaunching = false
            return
        }

        // Defer rebuild if the drawer is hidden; apply when it becomes visible
        if (!drawerVisible) {
            _pendingRebuild = true
            return
        }
        _pendingRebuild = false

        filteredModel.clear()
        selectedIndex = 0
        keyboardNavigationActive = false

        let apps = []
        if (searchQuery.length === 0) {
            apps = selectedCategory === "All"
                ? AppSearchService.getAppsInCategory("All")
                : AppSearchService.getAppsInCategory(selectedCategory).slice(0, maxResults)
        } else {
            if (selectedCategory === "All") {
                apps = AppSearchService.searchApplications(searchQuery)
            } else {
                const categoryApps = AppSearchService.getAppsInCategory(selectedCategory)
                if (categoryApps.length > 0) {
                    const allSearchResults = AppSearchService.searchApplications(searchQuery)
                    const categoryNames = new Set(categoryApps.map(app => app.name))
                    apps = allSearchResults.filter(
                        searchApp => categoryNames.has(searchApp.name)
                    ).slice(0, maxResults)
                }
                // else apps stays []
            }
        }

        // Sort alphabetically only when not searching (search results are already ranked)
        if (searchQuery.length === 0) {
            apps = apps.sort((a, b) => (a.name || "").localeCompare(b.name || ""))
        }

        // Single batch append — avoids repeated signal emissions
        const len = apps.length
        for (let i = 0; i < len; i++) {
            const app = apps[i]
            if (app) {
                filteredModel.append({
                    "name":        app.name        || "",
                    "exec":        app.execString  || "",
                    "icon":        app.icon        || "application-x-executable",
                    "comment":     app.comment     || "",
                    "categories":  app.categories  || [],
                    "desktopEntry": app
                })
            }
        }
    }

    // ── Navigation helpers ────────────────────────────────────────────────────
    function selectNext() {
        if (filteredModel.count === 0) return
        keyboardNavigationActive = true
        selectedIndex = viewMode === "grid"
            ? Math.min(selectedIndex + gridColumns, filteredModel.count - 1)
            : Math.min(selectedIndex + 1,           filteredModel.count - 1)
    }

    function selectPrevious() {
        if (filteredModel.count === 0) return
        keyboardNavigationActive = true
        selectedIndex = viewMode === "grid"
            ? Math.max(selectedIndex - gridColumns, 0)
            : Math.max(selectedIndex - 1,           0)
    }

    function selectNextInRow() {
        if (filteredModel.count === 0 || viewMode !== "grid") return
        keyboardNavigationActive = true
        selectedIndex = Math.min(selectedIndex + 1, filteredModel.count - 1)
    }

    function selectPreviousInRow() {
        if (filteredModel.count === 0 || viewMode !== "grid") return
        keyboardNavigationActive = true
        selectedIndex = Math.max(selectedIndex - 1, 0)
    }

    function launchSelected() {
        if (filteredModel.count === 0 || selectedIndex < 0 || selectedIndex >= filteredModel.count) return
        launchApp(filteredModel.get(selectedIndex))
    }

    function launchApp(appData) {
        if (!appData) return
        suppressUpdatesWhileLaunching = true
        SessionService.launchDesktopEntry(appData.desktopEntry)
        appLaunched(appData)
        AppUsageHistoryData.addAppUsage(appData.desktopEntry)
    }

    function setCategory(category) {
        selectedCategory = category
        categorySelected(category)
    }

    function setViewMode(mode) {
        viewMode = mode
        viewModeSelected(mode)
    }

    // ── Reactivity ────────────────────────────────────────────────────────────
    onSearchQueryChanged: {
        if (debounceSearch) {
            searchDebounceTimer.restart()
        } else {
            updateFilteredModel()
        }
    }
    onSelectedCategoryChanged:   updateFilteredModel()
    // Only rebuild on usage change if the ranking object reference actually changed
    onAppUsageRankingChanged:    updateFilteredModel()
    on_WatchApplicationsChanged: updateFilteredModel()

    // Apply deferred rebuild as soon as the drawer becomes visible
    onDrawerVisibleChanged: {
        if (drawerVisible && _pendingRebuild) {
            updateFilteredModel()
        }
    }

    Component.onCompleted: updateFilteredModel()

    // ── Model & debounce timer ────────────────────────────────────────────────
    ListModel { id: filteredModel }

    Timer {
        id: searchDebounceTimer
        interval: root.debounceInterval
        repeat:   false
        onTriggered: updateFilteredModel()
    }
}
