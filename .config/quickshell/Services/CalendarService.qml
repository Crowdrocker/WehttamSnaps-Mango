pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import Qt.labs.platform as Platform
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Common

Singleton {
    id: root

    property bool khalAvailable: false
    property bool demoMode: false
    property var eventsByDate: ({})
    property bool isLoading: false
    property string lastError: ""
    property date lastStartDate
    property date lastEndDate
    property string khalDateFormat: "MM/dd/yyyy"
    readonly property string homeDir: Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")
    readonly property string configDir: Platform.StandardPaths.writableLocation(Platform.StandardPaths.ConfigLocation).toString().replace(/^file:\/\//, "")
    readonly property string khalConfigPath: configDir + "/khal/config"
    property var calendarDirs: []   // array of absolute vdir paths from khal config

    // Local storage (works even without khal configured)
    readonly property string stateDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericStateLocation)) + "/EventHorizon"
    readonly property string localEventsPath: stateDir + "/calendar-events.json"
    property var localEvents: [] // array of plain objects
    property bool localStorageReady: false
    property string _pendingLocalWrite: ""

    // Notifications
    property int notifyLeadMinutes: 5
    property var _notifiedKeys: ({}) // key -> true
    property var _nextReminder: null // { ev, triggerMs }

    // "Remove Event" should always work at least for local storage.
    readonly property bool canDelete: true

    function checkKhalAvailability() {
        if (!khalCheckProcess.running)
            khalCheckProcess.running = true
    }

    function detectKhalDateFormat() {
        if (!khalFormatProcess.running)
            khalFormatProcess.running = true
    }

    function parseKhalDateFormat(formatExample) {
        let qtFormat = formatExample.replace("12", "MM").replace("21", "dd").replace("2013", "yyyy")
        return { format: qtFormat, parser: null }
    }


    function loadCurrentMonth() {
        let today = new Date()
        let firstDay = new Date(today.getFullYear(), today.getMonth(), 1)
        let lastDay = new Date(today.getFullYear(), today.getMonth() + 1, 0)
        let startDate = new Date(firstDay)
        startDate.setDate(startDate.getDate() - firstDay.getDay() - 7)
        let endDate = new Date(lastDay)
        endDate.setDate(endDate.getDate() + (6 - lastDay.getDay()) + 7)
        root.lastStartDate = startDate
        root.lastEndDate = endDate

        // Local storage is always present
        rebuildEventsByDateFromLocal()

        // Optional overlay/refresh from khal if available
        if (root.khalAvailable) {
            root.demoMode = false
            loadEvents(startDate, endDate)
        } else {
            root.demoMode = false
        }
    }

    function loadEvents(startDate, endDate) {
        if (!root.khalAvailable) {
            return
        }
        if (eventsProcess.running) {
            return
        }
        root.lastStartDate = startDate
        root.lastEndDate = endDate
        root.isLoading = true
        let startDateStr = Qt.formatDate(startDate, root.khalDateFormat)
        let endDateStr = Qt.formatDate(endDate, root.khalDateFormat)
        eventsProcess.requestStartDate = startDate
        eventsProcess.requestEndDate = endDate
        eventsProcess.command = ["khal", "list",
                                 "--json", "title",
                                 "--json", "description",
                                 "--json", "uid",
                                 "--json", "start-date",
                                 "--json", "start-time",
                                 "--json", "end-date",
                                 "--json", "end-time",
                                 "--json", "all-day",
                                 "--json", "location",
                                 "--json", "url",
                                 "--json", "categories",
                                 startDateStr, endDateStr]
        eventsProcess.running = true
    }

    function getEventsForDate(date) {
        let dateKey = Qt.formatDate(date, "yyyy-MM-dd")
        return root.eventsByDate[dateKey] || []
    }

    function hasEventsForDate(date) {
        let events = getEventsForDate(date)
        return events.length > 0
    }

    function _categoryFromKhal(eventObj) {
        // khal categories comes back as a string or array depending on backend/version.
        let cats = eventObj.categories
        if (!cats) return "Work"
        let list = []
        if (cats instanceof Array) list = cats
        else list = ("" + cats).split(",")
        for (let i = 0; i < list.length; i++) {
            const c = ("" + list[i]).trim().toLowerCase()
            if (c === "urgent") return "Urgent"
            if (c === "personal") return "Personal"
            if (c === "work") return "Work"
        }
        return "Work"
    }

    function loadDemoEvents(startDate, endDate) {
        // Lightweight placeholder data so the module is previewable without khal.
        root.isLoading = true
        let newEventsByDate = {}
        const today = new Date()

        function addEvent(d, title, category, hour, minute, durationMinutes, allDay) {
            const dateKey = Qt.formatDate(d, "yyyy-MM-dd")
            if (!newEventsByDate[dateKey]) newEventsByDate[dateKey] = []
            let start = new Date(d)
            let end = new Date(d)
            if (allDay) {
                start.setHours(0, 0, 0, 0)
                end.setHours(23, 59, 59, 999)
            } else {
                start.setHours(hour, minute, 0, 0)
                end = new Date(start.getTime() + durationMinutes * 60000)
            }
            newEventsByDate[dateKey].push({
                id: "demo_" + title.replace(/\s+/g, "_") + "_" + dateKey + "_" + (allDay ? "allday" : (hour + "_" + minute)),
                title,
                start,
                end,
                location: "",
                description: root.khalAvailable ? "" : "Demo event (khal not available)",
                url: "",
                calendar: "",
                color: "",
                allDay: !!allDay,
                isMultiDay: false,
                category
            })
        }

        // sprinkle a few events around "today"
        let d0 = new Date(today); d0.setHours(0, 0, 0, 0)
        let d1 = new Date(d0); d1.setDate(d1.getDate() - 1)
        let d2 = new Date(d0); d2.setDate(d2.getDate() + 1)
        addEvent(d0, "Standup", "Work", 9, 0, 15, false)
        addEvent(d0, "Focus block", "Work", 10, 0, 90, false)
        addEvent(d0, "Gym", "Personal", 18, 0, 60, false)
        addEvent(d1, "Pay rent", "Urgent", 0, 0, 0, true)
        addEvent(d2, "Call family", "Personal", 20, 0, 30, false)

        // sort per-day
        for (let dateKey in newEventsByDate) {
            newEventsByDate[dateKey].sort((a, b) => a.start.getTime() - b.start.getTime())
        }
        root.eventsByDate = newEventsByDate
        root.lastError = root.khalAvailable ? "" : "khal not found — showing demo events"
        root.isLoading = false
    }

    function ensureStateDir() {
        if (ensureDirProcess.running) return
        ensureDirProcess.command = ["mkdir", "-p", root.stateDir]
        ensureDirProcess.running = true
    }

    function rebuildEventsByDateFromLocal() {
        let byDate = {}
        const list = root.localEvents || []
        for (let i = 0; i < list.length; i++) {
            const e = list[i]
            const start = (e.start instanceof Date) ? e.start : new Date(e.start)
            const end = (e.end instanceof Date) ? e.end : new Date(e.end)
            if (isNaN(start.getTime())) continue
            const dateKey = Qt.formatDate(start, "yyyy-MM-dd")
            if (!byDate[dateKey]) byDate[dateKey] = []
            byDate[dateKey].push({
                id: e.id || "",
                uid: e.uid || "",
                title: e.title || "Untitled Event",
                start,
                end: isNaN(end.getTime()) ? new Date(start.getTime() + 3600000) : end,
                location: e.location || "",
                description: e.description || "",
                url: e.url || "",
                calendar: "",
                color: "",
                allDay: !!e.allDay,
                isMultiDay: false,
                category: e.category || "Work"
            })
        }
        for (let k in byDate)
            byDate[k].sort((a, b) => a.start.getTime() - b.start.getTime())
        root.eventsByDate = byDate
        scheduleReminderScan()
    }

    function saveLocalEvents() {
        ensureStateDir()
        const out = (root.localEvents || []).map(e => ({
            id: e.id || "",
            uid: e.uid || "",
            title: e.title || "",
            category: e.category || "Work",
            start: (e.start instanceof Date) ? e.start.toISOString() : (e.start || ""),
            end: (e.end instanceof Date) ? e.end.toISOString() : (e.end || ""),
            description: e.description || "",
            location: e.location || "",
            url: e.url || "",
            allDay: !!e.allDay
        }))
        const payload = JSON.stringify({ version: 1, events: out }, null, 2)
        if (!root.localStorageReady) {
            root._pendingLocalWrite = payload
            return
        }
        localEventsFile.setText(payload)
    }

    function upsertLocalEvent(ev) {
        const start = ev.start instanceof Date ? ev.start : new Date()
        const id = ev.id || ("local_" + (ev.title || "event") + "_" + start.getTime())
        let next = (root.localEvents || []).slice()
        const idx = next.findIndex(e => (e.id || "") === id)
        const obj = Object.assign({}, ev, { id })
        if (idx >= 0) next[idx] = obj
        else next.push(obj)
        root.localEvents = next
        saveLocalEvents()
        rebuildEventsByDateFromLocal()
    }

    function removeLocalEventById(id) {
        if (!id) return
        root.localEvents = (root.localEvents || []).filter(e => (e.id || "") !== id)
        saveLocalEvents()
        rebuildEventsByDateFromLocal()
    }

    function scheduleReminderScan() {
        // Kick the scanner quickly after event set changes.
        reminderScanSoon.restart()
        rescheduleNextReminder()
    }

    function _reminderKey(ev, triggerMs) {
        return (ev.id || ev.uid || ev.title || "event") + "|" + triggerMs
    }

    function scanAndNotifyUpcoming() {
        const now = Date.now()
        const leaEH = Math.max(0, root.notifyLeadMinutes) * 60000
        const lookbackMs = 45000
        const lookaheaEH = 120000
        const list = root.localEvents || []

        for (let i = 0; i < list.length; i++) {
            const e = list[i]
            if (!e) continue
            if (e.allDay) continue

            const start = (e.start instanceof Date) ? e.start : new Date(e.start)
            if (isNaN(start.getTime())) continue

            const trigger = start.getTime() - leaEH
            if (trigger < now - lookbackMs) continue
            if (trigger > now + lookaheaEH) continue

            const key = _reminderKey(e, trigger)
            if (root._notifiedKeys[key]) continue
            root._notifiedKeys[key] = true

            const when = Qt.formatTime(start, "h:mm AP")
            const body = (root.notifyLeadMinutes > 0)
                ? ("Starts at " + when + " (" + root.notifyLeadMinutes + " min)")
                : ("Starts at " + when)

            NotificationService.pushLocal(e.title || "Event", body, {
                appName: "Calendar",
                appIcon: "calendar_today"
            })
        }
    }

    function rescheduleNextReminder() {
        const now = Date.now()
        const leaEH = Math.max(0, root.notifyLeadMinutes) * 60000
        let best = null

        const list = root.localEvents || []
        for (let i = 0; i < list.length; i++) {
            const e = list[i]
            if (!e || e.allDay) continue
            const start = (e.start instanceof Date) ? e.start : new Date(e.start)
            if (isNaN(start.getTime())) continue
            const trigger = start.getTime() - leaEH
            if (trigger < now - 60000) continue // too far in past
            const key = _reminderKey(e, trigger)
            if (root._notifiedKeys[key]) continue
            if (!best || trigger < best.triggerMs) best = { ev: e, triggerMs: trigger }
        }

        root._nextReminder = best

        if (!best) {
            nextReminderTimer.stop()
            return
        }

        const delay = Math.max(0, best.triggerMs - now)
        nextReminderTimer.interval = Math.max(250, Math.min(2147483647, delay))
        nextReminderTimer.restart()
    }

    function fireNextReminder() {
        if (!root._nextReminder || !root._nextReminder.ev) {
            rescheduleNextReminder()
            return
        }
        const e = root._nextReminder.ev
        const trigger = root._nextReminder.triggerMs
        const key = _reminderKey(e, trigger)
        if (!root._notifiedKeys[key]) {
            root._notifiedKeys[key] = true
            const start = (e.start instanceof Date) ? e.start : new Date(e.start)
            const when = Qt.formatTime(start, "h:mm AP")
            const body = (root.notifyLeadMinutes > 0)
                ? ("Starts at " + when + " (" + root.notifyLeadMinutes + " min)")
                : ("Starts at " + when)
            NotificationService.pushLocal(e.title || "Event", body, { appName: "Calendar", appIcon: "calendar_today" })
        }
        rescheduleNextReminder()
    }

    function createEvent(ev) {
        // Persist locally so add/edit/remove always works.
        upsertLocalEvent({
            id: ev.id || "",
            uid: ev.uid || "",
            title: ev.title || "Untitled Event",
            start: ev.start instanceof Date ? ev.start : new Date(),
            end: ev.end instanceof Date ? ev.end : new Date((ev.start instanceof Date ? ev.start : new Date()).getTime() + 3600000),
            location: ev.location || "",
            description: ev.description || "",
            url: ev.url || "",
            allDay: !!ev.allDay,
            category: ev.category || "Work"
        })

        if (!root.khalAvailable) return
        if (createProcess.running) return

        const start = ev.start instanceof Date ? ev.start : new Date()
        const end = ev.end instanceof Date ? ev.end : new Date(start.getTime() + 3600000)

        // Prefer explicit datetimes to avoid locale parsing surprises.
        const startStr = Qt.formatDateTime(start, "yyyy-MM-dd hh:mm")
        const endStr = Qt.formatDateTime(end, "yyyy-MM-dd hh:mm")
        const summary = ev.title || "Untitled Event"
        const desc = ev.description || ""

        let cmd = ["khal", "new"]
        if (ev.category) cmd.push("-g", ev.category)
        if (ev.location) cmd.push("-l", ev.location)
        if (ev.url) cmd.push("--url", ev.url)

        if (ev.allDay) {
            // all-day: pass dates only
            cmd.push(Qt.formatDate(start, "yyyy-MM-dd"), Qt.formatDate(end, "yyyy-MM-dd"), summary)
        } else {
            cmd.push(startStr, endStr, summary)
        }
        if (desc && desc.length > 0) cmd.push("::", desc)

        createProcess.command = cmd
        createProcess.running = true
    }

    function deleteEvent(ev) {
        if (ev && ev.id) removeLocalEventById(ev.id)
        if (!root.khalAvailable) return

        if (root.calendarDirs.length === 0) {
            root.lastError = ""
            return
        }
        if (findUidProcess.running || rmProcess.running) return

        const uid = ev && ev.uid ? ("" + ev.uid).trim() : ""
        if (uid) {
            // Locate .ics containing UID then remove it.
            // We search for an exact UID line to avoid false matches.
            const pattern = "UID:" + uid
            const cmd = ["sh", "-c", "rg -l --fixed-strings '" + pattern.replace(/'/g, "'\\''") + "' " + root.calendarDirs.map(d => "'" + d.replace(/'/g, "'\\''") + "'").join(" ") + " | head -n 1"]
            findUidProcess.pendingUid = uid
            findUidProcess.command = cmd
            findUidProcess.running = true
            return
        }

        // Fallback: try to locate the ics by title + DTSTART when uid isn't exposed by khal.
        const title = (ev && ev.title ? ("" + ev.title) : "").trim()
        if (!title || !start) {
            root.lastError = "Can't remove: missing title or start time"
            return
        }

        const y = start.getFullYear().toString()
        const m = (start.getMonth() + 1).toString().padStart(2, "0")
        const d = start.getDate().toString().padStart(2, "0")
        const hh = start.getHours().toString().padStart(2, "0")
        const mm = start.getMinutes().toString().padStart(2, "0")
        const ymd = y + m + d
        const dtNeedle = (ev.allDay ? (":" + ymd) : (ymd + "T" + hh + mm))

        // Search strategy:
        // 1) find files with SUMMARY:<title> (fixed string)
        // 2) filter to those containing DTSTART.*<dtNeedle>
        // 3) take first match and rm
        const summaryNeedle = "SUMMARY:" + title
        const cmd2 =
            "rg -l --fixed-strings '" + summaryNeedle.replace(/'/g, "'\\''") + "' " +
            root.calendarDirs.map(d => "'" + d.replace(/'/g, "'\\''") + "'").join(" ") +
            " | xargs -r rg -l 'DTSTART[^\\n]*" + dtNeedle.replace(/'/g, "'\\''") + "' | head -n 1"

        findUidProcess.pendingUid = ""
        findUidProcess.command = ["sh", "-c", cmd2]
        findUidProcess.running = true
    }

    Component.onCompleted: {
        detectKhalDateFormat()
        ensureStateDir()
        khalConfigCheck.command = ["test", "-f", root.khalConfigPath]
        khalConfigCheck.running = true
    }

    Timer {
        id: reminderScanTimer
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.scanAndNotifyUpcoming()
            root.rescheduleNextReminder()
        }
    }

    Timer {
        id: reminderScanSoon
        interval: 250
        repeat: false
        onTriggered: {
            root.scanAndNotifyUpcoming()
            root.rescheduleNextReminder()
        }
    }

    Timer {
        id: nextReminderTimer
        interval: 1000
        repeat: false
        running: false
        onTriggered: root.fireNextReminder()
    }

    Process {
        id: khalConfigCheck
        running: false
        onExited: exitCode => {
            if (exitCode === 0) {
                khalConfigFile.path = root.khalConfigPath
            } else {
                root.calendarDirs = []
            }
        }
    }

    FileView {
        id: khalConfigFile
        blockLoading: false
        blockWrites: true
        preload: true

        onLoaded: {
            root.calendarDirs = root._parseKhalCalendarDirs(text())
        }
        onLoadFailed: {
            root.calendarDirs = []
        }
    }

    FileView {
        id: localEventsFile
        blockWrites: false
        atomicWrites: true
        preload: true

        onLoaded: {
            try {
                const data = JSON.parse(text() || "{}")
                const items = data.events || []
                root.localEvents = items.map(e => ({
                    id: e.id || "",
                    uid: e.uid || "",
                    title: e.title || "",
                    category: e.category || "Work",
                    start: e.start ? new Date(e.start) : new Date(),
                    end: e.end ? new Date(e.end) : new Date(),
                    description: e.description || "",
                    location: e.location || "",
                    url: e.url || "",
                    allDay: !!e.allDay
                }))
            } catch (e) {
                root.localEvents = []
            }
            rebuildEventsByDateFromLocal()
        }

        onLoadFailed: {
            root.localEvents = []
            rebuildEventsByDateFromLocal()
        }
    }

    Process {
        id: ensureDirProcess
        running: false
        onExited: exitCode => {
            root.localStorageReady = (exitCode === 0)
            if (root.localStorageReady) {
                localEventsInitProcess.command = ["sh", "-c",
                    "test -f \"$0\" || printf '%s' '{\"version\":1,\"events\":[]}' > \"$0\"",
                    root.localEventsPath
                ]
                localEventsInitProcess.running = true
            } else {
                root.lastError = "Calendar local storage init failed (mkdir exit " + exitCode + ")"
            }
        }
    }

    Process {
        id: localEventsInitProcess
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = "Calendar local storage init failed (init exit " + exitCode + ")"
                return
            }
            localEventsFile.path = root.localEventsPath
            if (root._pendingLocalWrite && root._pendingLocalWrite.length > 0) {
                localEventsFile.setText(root._pendingLocalWrite)
                root._pendingLocalWrite = ""
            }
        }
    }

    function _parseKhalCalendarDirs(configText) {
        // Very small INI-ish parser for khal's nested calendars:
        // [calendars]
        // [[name]]
        // path = /some/dir
        // We accept multiple and return existing "path" values.
        let dirs = []
        try {
            const lines = (configText || "").split("\n")
            let inCalendars = false
            for (let i = 0; i < lines.length; i++) {
                let line = lines[i].trim()
                if (!line || line.startsWith("#") || line.startsWith(";")) continue
                if (line.startsWith("[") && line.endsWith("]")) {
                    inCalendars = (line === "[calendars]")
                    continue
                }
                if (!inCalendars) continue
                // within [calendars], ignore section headers like [[foo]]
                const m = line.match(/^path\s*=\s*(.+)\s*$/)
                if (m) {
                    let p = m[1].trim()
                    // strip quotes
                    p = p.replace(/^"(.*)"$/, "$1").replace(/^'(.*)'$/, "$1")
                    // expand ~
                    if (p.startsWith("~/")) p = root.homeDir + p.slice(1)
                    if (p === "~") p = root.homeDir
                    dirs.push(p)
                }
            }
        } catch (e) {
            return []
        }
        // de-dupe
        let seen = ({})
        return dirs.filter(d => {
            if (!d) return false
            if (seen[d]) return false
            seen[d] = true
            return true
        })
    }

    Process {
        id: khalFormatProcess

        command: ["khal", "printformats"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                checkKhalAvailability()
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.split('\n')
                for (let line of lines) {
                    if (line.startsWith('dateformat:')) {
                        let formatExample = line.substring(line.indexOf(':') + 1).trim()
                        let formatInfo = parseKhalDateFormat(formatExample)
                        root.khalDateFormat = formatInfo.format
                        break
                    }
                }
                checkKhalAvailability()
            }
        }
    }

    Process {
        id: khalCheckProcess

        command: ["khal", "list", "today"]
        running: false
        onExited: exitCode => {
            root.khalAvailable = (exitCode === 0)
            if (exitCode === 0) {
                loadCurrentMonth()
            } else {
                root.demoMode = true
                loadCurrentMonth()
            }
        }
    }

    Process {
        id: eventsProcess

        property date requestStartDate
        property date requestEndDate
        property string rawOutput: ""

        running: false
        onExited: exitCode => {
            root.isLoading = false
            if (exitCode !== 0) {
                root.lastError = "Failed to load events (exit code: " + exitCode + ")"
                return
            }
            try {
                let newEventsByDate = {}
                let lines = eventsProcess.rawOutput.split('\n')
                for (let line of lines) {
                    line = line.trim()
                    if (!line || line === "[]")
                    continue

                    let dayEvents = JSON.parse(line)
                    for (let event of dayEvents) {
                        if (!event.title)
                        continue

                        let startDate, endDate
                        if (event['start-date']) {
                            startDate = Date.fromLocaleString(Qt.locale(), event['start-date'], root.khalDateFormat)
                        } else {
                            startDate = new Date()
                        }
                        if (event['end-date']) {
                            endDate = Date.fromLocaleString(Qt.locale(), event['end-date'], root.khalDateFormat)
                        } else {
                            endDate = new Date(startDate)
                        }
                        let startTime = new Date(startDate)
                        let endTime = new Date(endDate)
                        if (event['start-time']
                            && event['all-day'] !== "True") {
                            let timeStr = event['start-time']
                            if (timeStr) {
                                let timeParts = timeStr.match(/(\d+):(\d+)/)
                                if (timeParts) {
                                    startTime.setHours(parseInt(timeParts[1]),
                                                       parseInt(timeParts[2]))
                                    if (event['end-time']) {
                                        let endTimeParts = event['end-time'].match(
                                            /(\d+):(\d+)/)
                                        if (endTimeParts)
                                        endTime.setHours(
                                            parseInt(endTimeParts[1]),
                                            parseInt(endTimeParts[2]))
                                    } else {
                                        endTime = new Date(startTime)
                                        endTime.setHours(
                                            startTime.getHours() + 1)
                                    }
                                }
                            }
                        }
                        let eventId = event.title + "_" + event['start-date']
                        + "_" + (event['start-time'] || 'allday')
                        let eventTemplate = {
                            "id": eventId,
                            "uid": event.uid || "",
                            "title": event.title || "Untitled Event",
                            "start": startTime,
                            "end": endTime,
                            "location": event.location || "",
                            "description": event.description || "",
                            "url": event.url || "",
                            "calendar": "",
                            "color": "",
                            "allDay": event['all-day'] === "True",
                            "isMultiDay": startDate.toDateString(
                                              ) !== endDate.toDateString(),
                            "category": root._categoryFromKhal(event)
                        }
                        let currentDate = new Date(startDate)
                        while (currentDate <= endDate) {
                            let dateKey = Qt.formatDate(currentDate,
                                                        "yyyy-MM-dd")
                            if (!newEventsByDate[dateKey])
                            newEventsByDate[dateKey] = []

                            let existingEvent = newEventsByDate[dateKey].find(
                                e => {
                                    return e.id === eventId
                                })
                            if (existingEvent) {
                                currentDate.setDate(currentDate.getDate() + 1)
                                continue
                            }
                            let dayEvent = Object.assign({}, eventTemplate)
                            if (currentDate.getTime() === startDate.getTime()) {
                                dayEvent.start = new Date(startTime)
                            } else {
                                dayEvent.start = new Date(currentDate)
                                if (!dayEvent.allDay)
                                dayEvent.start.setHours(0, 0, 0, 0)
                            }
                            if (currentDate.getTime() === endDate.getTime()) {
                                dayEvent.end = new Date(endTime)
                            } else {
                                dayEvent.end = new Date(currentDate)
                                if (!dayEvent.allDay)
                                dayEvent.end.setHours(23, 59, 59, 999)
                            }
                            newEventsByDate[dateKey].push(dayEvent)
                            currentDate.setDate(currentDate.getDate() + 1)
                        }
                    }
                }
                for (let dateKey in newEventsByDate) {
                    newEventsByDate[dateKey].sort((a, b) => {
                                                      return a.start.getTime(
                                                          ) - b.start.getTime()
                                                  })
                }
                root.eventsByDate = newEventsByDate
                root.lastError = ""
            } catch (error) {
                root.lastError = "Failed to parse events JSON: " + error.toString()
                root.eventsByDate = {}
            }
            eventsProcess.rawOutput = ""
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                eventsProcess.rawOutput += data + "\n"
            }
        }
    }

    Process {
        id: createProcess
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = "Failed to create event (exit code: " + exitCode + ")"
            } else if (root.lastStartDate && root.lastEndDate) {
                // reload to pick up canonical IDs/categories from khal
                loadEvents(root.lastStartDate, root.lastEndDate)
            } else {
                loadCurrentMonth()
            }
        }
    }

    Process {
        id: findUidProcess
        property string pendingUid: ""
        running: false
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = "Delete failed: couldn't search calendar dirs"
                return
            }
            const filePath = (stdout.text || "").trim().split("\n")[0].trim()
            if (!filePath) {
                root.lastError = "Delete failed: couldn't find event file for UID " + pendingUid
                return
            }
            rmProcess.filePath = filePath
            rmProcess.running = true
        }
    }

    Process {
        id: rmProcess
        property string filePath: ""
        command: filePath ? ["rm", "-f", filePath] : ["true"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = "Delete failed (rm exit " + exitCode + ")"
            } else {
                root.lastError = ""
                if (root.lastStartDate && root.lastEndDate) loadEvents(root.lastStartDate, root.lastEndDate)
                else loadCurrentMonth()
            }
        }
    }

    Component.onDestruction: {
        if (khalFormatProcess.running) {
            khalFormatProcess.running = false
        }
        if (khalCheckProcess.running) {
            khalCheckProcess.running = false
        }
        if (eventsProcess.running) {
            eventsProcess.running = false
        }
    }
}
