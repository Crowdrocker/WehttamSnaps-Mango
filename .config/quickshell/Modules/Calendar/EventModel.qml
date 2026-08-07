import QtQuick

// Event model for CalendarPlan
// Defines the structure of an event object used throughout the calendar system
QtObject {
    id: eventModel

    // Unique identifier for the event
    property string id: ""

    // Title of the event
    property string title: ""

    // Category of the event (Work, Personal, Urgent)
    property string category: ""

    // Date of the event (for all-day events or start date)
    property date date: undefined

    // Start time of the event (if not all-day)
    property date startTime: undefined

    // End time of the event (if not all-day)
    property date endTime: undefined

    // Description or notes for the event
    property string description: ""

    // Whether the event is all-day
    property bool allDay: false
}