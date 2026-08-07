import QtQuick

// Calendar state management for CalendarPlan
// Manages reactive state for the calendar including current month, year, selected date, and events
QtObject {
    id: calendarState

    // Current month being displayed (0-11, where 0 is January)
    property int currentMonth: new Date().getMonth()

    // Current year being displayed
    property int currentYear: new Date().getFullYear()

    // Currently selected date
    property date selectedDate: new Date()

    // Events organized by date (key: "yyyy-MM-dd", value: array of events)
    property var eventsByDate: {}

    // Whether events are currently being loaded
    property bool isLoading: false

    // Last error message if any occurred during event loading
    property string lastError: ""

    // Update the current month and year
    function setCurrentMonth(year, month) {
        currentYear = year
        currentMonth = month
    }

    // Update the selected date
    function setSelectedDate(date) {
        selectedDate = date
    }

    // Update events for a specific date
    function setEventsForDate(dateKey, events) {
        eventsByDate[dateKey] = events
    }

    // Get events for a specific date
    function getEventsForDate(date) {
        let dateKey = Qt.formatDate(date, "yyyy-MM-dd")
        return eventsByDate[dateKey] || []
    }

    // Clear all events
    function clearEvents() {
        eventsByDate = {}
    }

    // Check if there are events for a specific date
    function hasEventsForDate(date) {
        return getEventsForDate(date).length > 0
    }

    // Set loading state
    function setLoading(loading) {
        isLoading = loading
    }

    // Set error message
    function setError(error) {
        lastError = error
    }

    // Clear error message
    function clearError() {
        lastError = ""
    }
}