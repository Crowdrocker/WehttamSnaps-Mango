pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.Common
import "../Common/markdown2html.js" as Markdown2Html

Singleton {
    id: root

    // Use var arrays to survive hot-reload (typed QML lists break when type id changes).
    property var notifications: []
    property var allWrappers: []
    readonly property var popups: allWrappers.filter(n => n && n.popup)

    property var notificationQueue: []
    property var visibleNotifications: []
    property int maxVisibleNotifications: (typeof SettingsData !== "undefined" && SettingsData.notificationMaxVisiblePopups !== undefined)
                                         ? SettingsData.notificationMaxVisiblePopups
                                         : 3
    property bool addGateBusy: false
    property int enterAnimMs: (typeof SettingsData !== "undefined" && SettingsData.notificationEnterAnimMs !== undefined)
                              ? SettingsData.notificationEnterAnimMs
                              : 400
    property int seqCounter: 0
    property bool bulkDismissing: false

    property int maxQueueSize: (typeof SettingsData !== "undefined" && SettingsData.notificationMaxQueueSize !== undefined)
                               ? SettingsData.notificationMaxQueueSize
                               : 32
    property int maxIngressPerSecond: (typeof SettingsData !== "undefined" && SettingsData.notificationMaxIngressPerSecond !== undefined)
                                      ? SettingsData.notificationMaxIngressPerSecond
                                      : 20
    property double _lastIngressSec: 0
    property int _ingressCountThisSec: 0
    property int maxStoredNotifications: (typeof SettingsData !== "undefined" && SettingsData.notificationMaxStored !== undefined)
                                         ? SettingsData.notificationMaxStored
                                         : 300
    property string _lastMprisKey: ""
    property double _lastMprisTime: 0
    readonly property int mprisDebounceMs: 500

    property var _dismissQueue: []
    property int _dismissBatchSize: (typeof SettingsData !== "undefined" && SettingsData.notificationDismissBatchSize !== undefined)
                                    ? SettingsData.notificationDismissBatchSize
                                    : 8
    property int _dismissTickMs: (typeof SettingsData !== "undefined" && SettingsData.notificationDismissTickMs !== undefined)
                                 ? SettingsData.notificationDismissTickMs
                                 : 8
    property bool _suspendGrouping: false
    property var _groupCache: ({
                                   "notifications": [],
                                   "popups": []
                               })
    property bool _groupsDirty: false

    Component.onCompleted: {
        _recomputeGroups()
    }

    function _nowSec() {
        return Date.now() / 1000.0
    }

    function _ingressAllowed(notif) {
        const t = _nowSec()
        if (t - _lastIngressSec >= 1.0) {
            _lastIngressSec = t
            _ingressCountThisSec = 0
        }
        _ingressCountThisSec += 1
        if (notif.urgency === NotificationUrgency.Critical) {
            return true
        }
        return _ingressCountThisSec <= maxIngressPerSecond
    }

    function _enqueuePopup(wrapper) {
        if (notificationQueue.length >= maxQueueSize) {
            const gk = getGroupKey(wrapper)
            let idx = notificationQueue.findIndex(w => w && getGroupKey(w) === gk && w.urgency !== NotificationUrgency.Critical)
            if (idx === -1) {
                idx = notificationQueue.findIndex(w => w && w.urgency !== NotificationUrgency.Critical)
            }
            if (idx === -1) {
                idx = 0
            }
            const victim = notificationQueue[idx]
            if (victim) {
                victim.popup = false
            }
            notificationQueue.splice(idx, 1)
        }
        notificationQueue = [...notificationQueue, wrapper]
    }

    function _initWrapperPersistence(wrapper) {
        const timeoutMs = wrapper.timer ? wrapper.timer.interval : 5000
        const isCritical = wrapper.notification && wrapper.notification.urgency === NotificationUrgency.Critical
        wrapper.isPersistent = isCritical || (timeoutMs === 0)
    }

    function _trimStored() {
        if (notifications.length > maxStoredNotifications) {
            const overflow = notifications.length - maxStoredNotifications
            const toDrop = []
            for (var i = notifications.length - 1; i >= 0 && toDrop.length < overflow; --i) {
                const w = notifications[i]
                if (w && w.notification && w.urgency !== NotificationUrgency.Critical) {
                    toDrop.push(w)
                }
            }
            for (var i = notifications.length - 1; i >= 0 && toDrop.length < overflow; --i) {
                const w = notifications[i]
                if (w && w.notification && toDrop.indexOf(w) === -1) {
                    toDrop.push(w)
                }
            }
            for (const w of toDrop) {
                try {
                    if (w && w.notification) {
                        w.notification.dismiss()
                    }
                } catch (e) {
                    if (typeof LoggingService !== 'undefined') {
                        LoggingService.warn("NotificationService", "Failed to dismiss notification", { error: e.message, notification: w?.notification?.id })
                    }
                }
            }
        }
    }

    function onOverlayOpen() {
        popupsDisabled = true
        addGate.stop()
        addGateBusy = false

        notificationQueue = []
        for (const w of visibleNotifications) {
            if (w) {
                w.popup = false
            }
        }
        visibleNotifications = []
        _recomputeGroupsLater()
    }

    function onOverlayClose() {
        popupsDisabled = false
        processQueue()
    }

    Timer {
        id: addGate
        interval: enterAnimMs + 50
        running: false
        repeat: false
        onTriggered: {
            addGateBusy = false
            processQueue()
        }
    }

    Timer {
        id: timeUpdateTimer
        interval: 30000
        repeat: true
        running: root.allWrappers.length > 0 || visibleNotifications.length > 0
        triggeredOnStart: false
        onTriggered: {
            root.timeUpdateTick = !root.timeUpdateTick
        }
    }

    Timer {
        id: dismissPump
        interval: _dismissTickMs
        repeat: true
        running: false
        onTriggered: {
            let n = Math.min(_dismissBatchSize, _dismissQueue.length)
            for (var i = 0; i < n; ++i) {
                const w = _dismissQueue.pop()
                try {
                    if (w && w.notification) {
                        w.notification.dismiss()
                    }
                } catch (e) {
                    if (typeof LoggingService !== 'undefined') {
                        LoggingService.warn("NotificationService", "Failed to dismiss notification in bulk dismiss", { error: e.message, notification: w?.notification?.id })
                    }
                }
            }
            if (_dismissQueue.length === 0) {
                dismissPump.stop()
                _suspendGrouping = false
                bulkDismissing = false
                popupsDisabled = false
                _recomputeGroupsLater()
            }
        }
    }

    Timer {
        id: groupsDebounce
        interval: 16
        repeat: false
        onTriggered: _recomputeGroups()
    }

    property bool timeUpdateTick: false
    property bool clockFormatChanged: false

    readonly property var groupedNotifications: _groupCache.notifications
    readonly property var groupedPopups: _groupCache.popups

    property var expandedGroups: ({})
    property var expandedMessages: ({})
    property bool popupsDisabled: false

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true

            if (!_ingressAllowed(notif)) {
                if (notif.urgency !== NotificationUrgency.Critical) {
                    try {
                        notif.dismiss()
                    } catch (e) {
                        if (typeof LoggingService !== 'undefined') {
                            LoggingService.warn("NotificationService", "Failed to dismiss rate-limited notification", { error: e.message, notificationId: notif.id })
                        }
                    }
                    return
                }
            }

            const shouldShowPopup = !root.popupsDisabled && !SessionData.doNotDisturb
            const wrapper = notifComponent.createObject(root, {
                                                            "popup": shouldShowPopup,
                                                            "notification": notif
                                                        })

            if (wrapper) {
                // Use array spread to avoid QML list type incompatibility warnings
                root.allWrappers = [...root.allWrappers, wrapper]
                root.notifications = [...root.notifications, wrapper]
                _trimStored()

                Qt.callLater(() => {
                                 _initWrapperPersistence(wrapper)
                             })

                if (shouldShowPopup) {
                    _enqueuePopup(wrapper)
                    processQueue()
                }
            }

            _recomputeGroupsLater()
        }
    }

    component NotifWrapper: QtObject {
        id: wrapper

        property bool popup: false
        property bool removedByLimit: false
        property bool isPersistent: true
        property int seq: 0

        onPopupChanged: {
            if (!popup) {
                removeFromVisibleNotifications(wrapper)
            }
        }

        readonly property Timer timer: Timer {
            interval: {
                if (!wrapper.notification) {
                    return 5000
                }

                switch (wrapper.notification.urgency) {
                    case NotificationUrgency.Low:
                    return SettingsData.notificationTimeoutLow
                    case NotificationUrgency.Critical:
                    return SettingsData.notificationTimeoutCritical
                    default:
                    return SettingsData.notificationTimeoutNormal
                }
            }
            repeat: false
            running: false
            onTriggered: {
                if (interval > 0) {
                    wrapper.popup = false
                }
            }
        }

        readonly property date time: new Date()
        readonly property string timeStr: {
            root.timeUpdateTick
            root.clockFormatChanged

            const now = new Date()
            const diff = now.getTime() - time.getTime()
            const minutes = Math.floor(diff / 60000)
            const hours = Math.floor(minutes / 60)

            if (hours < 1) {
                if (minutes < 1) {
                    return "now"
                }
                return `${minutes}m ago`
            }

            const nowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate())
            const timeDate = new Date(time.getFullYear(), time.getMonth(), time.getDate())
            const daysDiff = Math.floor((nowDate - timeDate) / (1000 * 60 * 60 * 24))

            if (daysDiff === 0) {
                return formatTime(time)
            }

            if (daysDiff === 1) {
                return `yesterday, ${formatTime(time)}`
            }

            return `${daysDiff} days ago`
        }

        function formatTime(date) {
            let use24Hour = true
            try {
                if (typeof SettingsData !== "undefined" && SettingsData.use24HourClock !== undefined) {
                    use24Hour = SettingsData.use24HourClock
                }
            } catch (e) {
                use24Hour = true
            }

            if (use24Hour) {
                const hours = date.getHours()
                const minutes = date.getMinutes()
                return String(hours).padStart(2, '0') + ":" + String(minutes).padStart(2, '0')
            } else {
                const formatted = date.toLocaleTimeString(Qt.locale(), "h:mm AP")
                return formatted.replace(/\./g, "").trim()
            }
        }

        // Some synthetic wrappers (e.g. MPRIS) don't have a real Notification.
        property var notification: null
        readonly property string summary: notification?.summary ?? ""
        readonly property string body: notification?.body ?? ""

        // Decode HTML entities browsers send, then markdown-convert if needed
        readonly property string htmlBody: {
            const b = body
            if (!b) return ""
            let t = b
                .replace(/&amp;/g,  "&")
                .replace(/&lt;/g,   "<")
                .replace(/&gt;/g,   ">")
                .replace(/&quot;/g, "\"")
                .replace(/&#39;/g,  "'")
                .replace(/&apos;/g, "'")
                .replace(/&nbsp;/g, "\u00a0")
            if (t.includes('<') && t.includes('>'))
                return t
            return Markdown2Html.markdownToHtml(t)
        }

        readonly property string appIcon: notification?.appIcon ?? ""

        // Clean display name — browsers / system daemons send ugly raw names
        readonly property string appName: {
            // 1. Try desktop entry for the canonical app name
            const de = notification?.desktopEntry
            if (de && de !== "") {
                const entry = DesktopEntries.heuristicLookup(de)
                if (entry && entry.name) return entry.name
            }
            const raw = (notification?.appName || "").trim()
            if (raw === "") return "App"
            // 2. Known name map
            const map = {
                // Browsers — native + Flatpak
                "chromium":                 "Chromium",
                "chromium-browser":         "Chromium",
                "google-chrome":            "Chrome",
                "google chrome":            "Chrome",
                "chrome":                   "Chrome",
                "microsoft-edge":           "Edge",
                "microsoft edge":           "Edge",
                "msedge":                   "Edge",
                "firefox":                  "Firefox",
                "firefox-esr":              "Firefox",
                "mozilla firefox":          "Firefox",
                "brave-browser":            "Brave",
                "brave":                    "Brave",
                "opera":                    "Opera",
                "vivaldi":                  "Vivaldi",
                "waterfox":                 "Waterfox",
                "librewolf":                "LibreWolf",
                "zen":                      "Zen",
                "zen-browser":              "Zen",
                "thorium":                  "Thorium",
                "ungoogled-chromium":       "Ungoogled Chromium",
                // Media
                "spotify":                  "Spotify",
                "vlc":                      "VLC",
                "mpv":                      "mpv",
                "rhythmbox":                "Rhythmbox",
                "cider":                    "Cider",
                "sh.cider.cider":           "Cider",
                "elisa":                    "Elisa",
                "lollypop":                 "Lollypop",
                "nuclear":                  "Nuclear",
                // Messaging
                "discord":                  "Discord",
                "slack":                    "Slack",
                "telegram":                 "Telegram",
                "telegram-desktop":         "Telegram",
                "org.telegram.desktop":     "Telegram",
                "signal":                   "Signal",
                "signal-desktop":           "Signal",
                "whatsapp":                 "WhatsApp",
                "element":                  "Element",
                "fractal":                  "Fractal",
                "thunderbird":              "Thunderbird",
                "evolution":                "Evolution",
                "geary":                    "Geary",
                "kmail":                    "KMail",
                "teams":                    "Teams",
                "webex":                    "Webex",
                "zoom":                     "Zoom",
                // System / daemons
                "networkmanager":           "Network",
                "network-manager":          "Network",
                "nm-applet":                "Network",
                "packagekitd":              "Software Updates",
                "gnome-software":           "Software",
                "flatpak":                  "Flatpak",
                "systemd":                  "System",
                "upowerd":                  "Power",
                "upower":                   "Power",
                "org.freedesktop.upower":   "Power",
                "notify-send":              "Notification",
                "dunst":                    "Notification",
            }
            const lower = raw.toLowerCase()
            if (map[lower]) return map[lower]
            // 3. Title-case if all lowercase (daemon names)
            if (raw === lower)
                return raw.charAt(0).toUpperCase() + raw.slice(1)
            return raw
        }

        // Desktop entry — inferred from appName when missing (browsers rarely send it)
        readonly property string desktopEntry: {
            if (notification?.desktopEntry && notification.desktopEntry !== "")
                return notification.desktopEntry
            const raw = (notification?.appName || "").toLowerCase()
            const inferMap = {
                "firefox":          "org.mozilla.firefox",
                "mozilla firefox":  "org.mozilla.firefox",
                "chromium":         "chromium",
                "google chrome":    "google-chrome",
                "chrome":           "google-chrome",
                "brave":            "com.brave.browser",
                "microsoft edge":   "com.microsoft.edge",
                "discord":          "discord",
                "slack":            "slack",
                "telegram":         "org.telegram.desktop",
                "signal":           "signal-desktop",
                "thunderbird":      "thunderbird",
                "spotify":          "spotify",
                "zoom":             "us.zoom.Zoom",
            }
            return inferMap[raw] || ""
        }

        readonly property string image: notification?.image ?? ""

        // Resolve image path — handles Flatpak sandbox remapping for all browsers
        readonly property string cleanImage: {
            if (!image) return ""
            let path = Paths.strip(image)

            // Generic Flatpak /run/user remapping — covers all browsers
            // Pattern: /run/user/UID/APP_ID/... → ~/.var/app/APP_ID/cache/tmp/FILE
            const runUserMatch = path.match(/^\/run\/user\/\d+\/([^/]+)\/(.+)$/)
            if (runUserMatch) {
                const appId  = runUserMatch[1]
                const rest   = runUserMatch[2]
                const home   = Quickshell.env("HOME")
                // Try common cache locations
                return `${home}/.var/app/${appId}/cache/tmp/${rest.split("/").pop()}`
            }

            // Cider/Chromium-based: /var/tmp/ → Flatpak cache
            if (path.includes(".org.chromium.Chromium") || path.includes("sh.cider.Cider")) {
                if (path.startsWith("/var/tmp/")) {
                    const home = Quickshell.env("HOME")
                    const appId = path.includes("sh.cider") ? "sh.cider.Cider" : "org.chromium.Chromium"
                    return `${home}/.var/app/${appId}/cache/tmp/${path.split("/").pop()}`
                }
            }

            return path
        }
        readonly property int urgency: notification?.urgency ?? 0
        readonly property list<NotificationAction> actions: notification?.actions ?? []

        readonly property Connections conn: Connections {
            target: wrapper.notification?.Retainable ?? null
            ignoreUnknownSignals: true

            function onDropped(): void {
                root.allWrappers = root.allWrappers.filter(w => w !== wrapper)
                root.notifications = root.notifications.filter(w => w !== wrapper)

                if (root.bulkDismissing) {
                    return
                }

                const groupKey = getGroupKey(wrapper)
                const remainingInGroup = root.notifications.filter(n => getGroupKey(n) === groupKey)

                if (remainingInGroup.length <= 1) {
                    clearGroupExpansionState(groupKey)
                }

                cleanupExpansionStates()
                root._recomputeGroupsLater()
            }

            function onAboutToDestroy(): void {
                wrapper.destroy()
            }
        }
    }

    Component {
        id: notifComponent
        NotifWrapper {}
    }

    function clearAllNotifications() {
        bulkDismissing = true
        popupsDisabled = true
        addGate.stop()
        addGateBusy = false
        notificationQueue = []

        for (const w of allWrappers)
            w.popup = false
        visibleNotifications = []

        _dismissQueue = notifications.slice()
        if (notifications.length) {
            notifications = []
        }
        expandedGroups = {}
        expandedMessages = {}

        _suspendGrouping = true

        if (!dismissPump.running && _dismissQueue.length) {
            dismissPump.start()
        }
    }

    function dismissNotification(wrapper) {
        if (!wrapper || !wrapper.notification) {
            return
        }
        wrapper.popup = false
        wrapper.notification.dismiss()
    }

    function disablePopups(disable) {
        popupsDisabled = disable
        if (disable) {
            notificationQueue = []
            for (const notif of visibleNotifications) {
                notif.popup = false
            }
            visibleNotifications = []
        }
    }

    function processQueue() {
        if (addGateBusy) {
            return
        }
        if (popupsDisabled) {
            return
        }
        if (SessionData.doNotDisturb) {
            return
        }
        if (notificationQueue.length === 0) {
            return
        }

        const next = notificationQueue.shift()
        if (!next) {
            return
        }

        // Lock gate before dismissing so processQueue won't be re-entered
        addGateBusy = true

        // Dismiss all currently visible notifications so only the newest shows
        for (const n of visibleNotifications.slice()) {
            if (n && n.popup) {
                n.popup = false
            }
        }

        next.seq = ++seqCounter
        visibleNotifications = [...visibleNotifications, next]
        next.popup = true

        if (next.timer.interval > 0) {
            next.timer.start()
        }

        addGate.restart()
    }

    function removeFromVisibleNotifications(wrapper) {
        visibleNotifications = visibleNotifications.filter(n => n !== wrapper)
        processQueue()
    }

    function releaseWrapper(w) {
        visibleNotifications = visibleNotifications.filter(n => n !== w)
        notificationQueue = notificationQueue.filter(n => n !== w)

        if (w && w.destroy && !w.isPersistent && notifications.indexOf(w) === -1) {
            Qt.callLater(() => {
                             try {
                                 w.destroy()
                             } catch (e) {

                             }
                         })
        }
    }

    function getGroupKey(wrapper) {
        if (wrapper.desktopEntry && wrapper.desktopEntry !== "") {
            return wrapper.desktopEntry.toLowerCase()
        }

        return wrapper.appName.toLowerCase()
    }

    function _recomputeGroups() {
        if (_suspendGrouping) {
            _groupsDirty = true
            return
        }
        _groupCache = {
            "notifications": _calcGroupedNotifications(),
            "popups": _calcGroupedPopups()
        }
        _groupsDirty = false
    }

    function _recomputeGroupsLater() {
        _groupsDirty = true
        if (!groupsDebounce.running) {
            groupsDebounce.start()
        }
    }

    function _calcGroupedNotifications() {
        const groups = {}

        for (const notif of notifications) {
            const groupKey = getGroupKey(notif)
            if (!groups[groupKey]) {
                groups[groupKey] = {
                    "key": groupKey,
                    "appName": notif.appName,
                    "notifications": [],
                    "latestNotification": null,
                    "count": 0,
                    "hasInlineReply": false
                }
            }

            groups[groupKey].notifications.unshift(notif)
            groups[groupKey].latestNotification = groups[groupKey].notifications[0]
            groups[groupKey].count = groups[groupKey].notifications.length

            if (notif.notification.hasInlineReply) {
                groups[groupKey].hasInlineReply = true
            }
        }

        return Object.values(groups).sort((a, b) => {
                                              const aUrgency = a.latestNotification.urgency || NotificationUrgency.Low
                                              const bUrgency = b.latestNotification.urgency || NotificationUrgency.Low
                                              if (aUrgency !== bUrgency) {
                                                  return bUrgency - aUrgency
                                              }
                                              return b.latestNotification.time.getTime() - a.latestNotification.time.getTime()
                                          })
    }

    function _calcGroupedPopups() {
        const groups = {}

        for (const notif of popups) {
            const groupKey = getGroupKey(notif)
            if (!groups[groupKey]) {
                groups[groupKey] = {
                    "key": groupKey,
                    "appName": notif.appName,
                    "notifications": [],
                    "latestNotification": null,
                    "count": 0,
                    "hasInlineReply": false
                }
            }

            groups[groupKey].notifications.unshift(notif)
            groups[groupKey].latestNotification = groups[groupKey].notifications[0]
            groups[groupKey].count = groups[groupKey].notifications.length

            if (notif.notification.hasInlineReply) {
                groups[groupKey].hasInlineReply = true
            }
        }

        return Object.values(groups).sort((a, b) => {
                                              return b.latestNotification.time.getTime() - a.latestNotification.time.getTime()
                                          })
    }

    function toggleGroupExpansion(groupKey) {
        let newExpandedGroups = {}
        for (const key in expandedGroups) {
            newExpandedGroups[key] = expandedGroups[key]
        }
        newExpandedGroups[groupKey] = !newExpandedGroups[groupKey]
        expandedGroups = newExpandedGroups
    }

    function dismissGroup(groupKey) {
        const group = groupedNotifications.find(g => g.key === groupKey)
        if (group) {
            for (const notif of group.notifications) {
                if (notif && notif.notification) {
                    notif.notification.dismiss()
                }
            }
        } else {
            for (const notif of allWrappers) {
                if (notif && notif.notification && getGroupKey(notif) === groupKey) {
                    notif.notification.dismiss()
                }
            }
        }
    }

    function clearGroupExpansionState(groupKey) {
        let newExpandedGroups = {}
        for (const key in expandedGroups) {
            if (key !== groupKey && expandedGroups[key]) {
                newExpandedGroups[key] = true
            }
        }
        expandedGroups = newExpandedGroups
    }

    function cleanupExpansionStates() {
        const currentGroupKeys = new Set(groupedNotifications.map(g => g.key))
        const currentMessageIds = new Set()
        for (const group of groupedNotifications) {
            for (const notif of group.notifications) {
                currentMessageIds.add(notif.notification.id)
            }
        }
        let newExpandedGroups = {}
        for (const key in expandedGroups) {
            if (currentGroupKeys.has(key) && expandedGroups[key]) {
                newExpandedGroups[key] = true
            }
        }
        expandedGroups = newExpandedGroups
        let newExpandedMessages = {}
        for (const messageId in expandedMessages) {
            if (currentMessageIds.has(messageId) && expandedMessages[messageId]) {
                newExpandedMessages[messageId] = true
            }
        }
        expandedMessages = newExpandedMessages
    }

    function toggleMessageExpansion(messageId) {
        let newExpandedMessages = {}
        for (const key in expandedMessages) {
            newExpandedMessages[key] = expandedMessages[key]
        }
        newExpandedMessages[messageId] = !newExpandedMessages[messageId]
        expandedMessages = newExpandedMessages
    }

    Connections {
        target: SessionData
        function onDoNotDisturbChanged() {
            if (SessionData.doNotDisturb) {
                for (const notif of visibleNotifications) {
                    notif.popup = false
                }
                visibleNotifications = []
                notificationQueue = []
            } else {
                processQueue()
            }
        }
    }

    // ── MPRIS track-change → notification ─────────────────────────────────────
    // Browsers expose media session via MPRIS, not D-Bus notifications.
    // We synthesise a popup when any MPRIS player changes track.
    Connections {
        // Track metadata lives on activePlayer, not controller singleton.
        // Use ignoreUnknownSignals to avoid warnings when target null/changes.
        target: MprisController.activePlayer
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            if (root.popupsDisabled || SessionData.doNotDisturb) return

            const player = MprisController.activePlayer
            if (!player) return

            const title = player.trackTitle || ""
            if (title === "") return
            const artist = player.trackArtist || ""
            const artUrl = player.trackArtUrl || ""
            const playerIdentity = player.identity || ""

            const key = title + "\n" + artist + "\n" + playerIdentity
            if (key === root._lastMprisKey) return
            root._lastMprisKey = key

            // Debounce rapid track changes (e.g. YouTube thumbnail hover).
            // Browsers briefly register each hover as a new MPRIS track, spamming
            // consecutive track-change notifications with different titles.
            const now = Date.now()
            if (now - root._lastMprisTime < root.mprisDebounceMs) return
            root._lastMprisTime = now

            // Resolve clean player name
            const idLow = playerIdentity.toLowerCase()
            let appName = playerIdentity
            if      (idLow.includes("edge"))      appName = "Edge"
            else if (idLow.includes("chrome"))    appName = "Chrome"
            else if (idLow.includes("chromium"))  appName = "Chromium"
            else if (idLow.includes("firefox"))   appName = "Firefox"
            else if (idLow.includes("brave"))     appName = "Brave"
            else if (idLow.includes("opera"))     appName = "Opera"
            else if (idLow.includes("vivaldi"))   appName = "Vivaldi"
            else if (idLow.includes("spotify"))   appName = "Spotify"
            else if (idLow.includes("vlc"))       appName = "VLC"
            else if (idLow.includes("cider"))     appName = "Cider"
            else if (idLow.includes("rhythmbox")) appName = "Rhythmbox"

            const body   = artist !== "" ? artist : ""
            const imgUrl = artUrl.startsWith("file://") ? artUrl.substring(7) : artUrl

            const wrapper = mprisNotifComponent.createObject(root, {
                "_title":      title,
                "_body":       body,
                "_appName":    appName,
                "_image":      imgUrl,
                "_appIcon":    idLow.includes("spotify") ? "spotify" : "audio-x-generic",
                "popup":       true,
            })

            if (!wrapper) return

            root.allWrappers = [...root.allWrappers, wrapper]
            // Don't add to persistent notifications list — media track changes are ephemeral
            _enqueuePopup(wrapper)
            processQueue()
            _recomputeGroupsLater()
        }
    }

    // Lightweight synthetic wrapper for MPRIS notifications (no real Notification object)
    Component {
        id: mprisNotifComponent

        QtObject {
            id: mprisWrapper

            property bool   popup:           false
            property bool   removedByLimit:  false
            property bool   isPersistent:    false
            property int    seq:             0
            property string _title:          ""
            property string _body:           ""
            property string _appName:        ""
            property string _image:          ""
            property string _appIcon:        "audio-x-generic"

            onPopupChanged: {
                if (!popup) removeFromVisibleNotifications(mprisWrapper)
            }

            readonly property Timer timer: Timer {
                interval: SettingsData.notificationTimeoutNormal || 4000
                repeat:   false
                running:  false
                onTriggered: mprisWrapper.popup = false
            }

            readonly property date   time:        new Date()
            readonly property string timeStr:     "now"
            readonly property string summary:     _title
            readonly property string body:        _body
            readonly property string htmlBody:    _body
            readonly property string appName:     _appName
            readonly property string appIcon:     _appIcon
            readonly property string desktopEntry: ""
            readonly property string image:       _image
            readonly property string cleanImage:  _image
            readonly property int    urgency:     1   // Normal
            readonly property var    actions:     []
            // Stub — no real notification to dismiss
            readonly property var    notification: QtObject {
                // Provide id/urgency so popup manager doesn't warn
                property string id: "mpris-" + Date.now() + "-" + Math.floor(Math.random() * 1000000)
                property int urgency: 1
                function dismiss() { mprisWrapper.popup = false }
            }
        }
    }

    // ── Synthetic notifications (for internal modules) ────────────────────────
    // Calendar reminders, timers, etc. Use the same wrapper shape as MPRIS.
    function pushLocal(summary, body, opts) {
        const o = opts || ({})
        const force = !!o.force
        if (!force && (root.popupsDisabled || SessionData.doNotDisturb)) return
        const wrapper = localNotifComponent.createObject(root, {
            "_title":   summary || "",
            "_body":    body || "",
            "_appName": o.appName || "Calendar",
            "_appIcon": o.appIcon || "calendar_today",
            "popup":    true,
            "_urgency": (o.urgency !== undefined ? o.urgency : 1)
        })
        if (!wrapper) return

        root.allWrappers = [...root.allWrappers, wrapper]
        if (force) {
            // Bypass gating/queue: show immediately.
            wrapper.seq = ++seqCounter
            visibleNotifications = [...visibleNotifications, wrapper]
            wrapper.popup = true
            if (wrapper.timer && wrapper.timer.interval > 0) {
                wrapper.timer.start()
            }
            _recomputeGroupsLater()
            return
        }

        _enqueuePopup(wrapper)
        processQueue()
        _recomputeGroupsLater()
    }

    Component {
        id: localNotifComponent

        QtObject {
            id: localWrapper

            property bool   popup:           false
            property bool   removedByLimit:  false
            property bool   isPersistent:    false
            property int    seq:             0
            property string _title:          ""
            property string _body:           ""
            property string _appName:        "Calendar"
            property string _appIcon:        "calendar_today"
            property int    _urgency:        1

            onPopupChanged: {
                if (!popup) removeFromVisibleNotifications(localWrapper)
            }

            readonly property Timer timer: Timer {
                interval: SettingsData.notificationTimeoutNormal || 5000
                repeat:   false
                running:  false
                onTriggered: localWrapper.popup = false
            }

            readonly property date   time:        new Date()
            readonly property string timeStr:     "now"
            readonly property string summary:     _title
            readonly property string body:        _body
            readonly property string htmlBody:    _body
            readonly property string appName:     _appName
            readonly property string appIcon:     _appIcon
            readonly property string desktopEntry: ""
            readonly property string image:       ""
            readonly property string cleanImage:  ""
            readonly property int    urgency:     _urgency   // Normal by default
            readonly property var    actions:     []
            // Stub — no real notification to dismiss
            readonly property var    notification: QtObject {
                // Provide id/urgency so popup manager doesn't warn
                property string id: "local-" + Date.now() + "-" + Math.floor(Math.random() * 1000000)
                property int urgency: localWrapper._urgency
                function dismiss() { localWrapper.popup = false }
            }
        }
    }

    Connections {
        target: typeof SettingsData !== "undefined" ? SettingsData : null
        function onUse24HourClockChanged() {
            root.clockFormatChanged = !root.clockFormatChanged
        }
    }

    /**
     * Cleanup on destruction: stop all timers to prevent resource leaks
     */
    Component.onDestruction: {
        if (addGate.running) {
            addGate.stop()
        }
        if (timeUpdateTimer.running) {
            timeUpdateTimer.stop()
        }
        if (dismissPump.running) {
            dismissPump.stop()
        }
        if (groupsDebounce.running) {
            groupsDebounce.stop()
        }
    }
}
