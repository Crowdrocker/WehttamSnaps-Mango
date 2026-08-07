import QtQuick

/**
 * Reusable debounce timer for search/filter operations.
 * 
 * Usage:
 *   SearchDebounceTimer {
 *       id: searchDebounce
 *       interval: 250  // optional, defaults to 250ms
 *       onTriggered: updateFilteredModel()
 *   }
 * 
 *   // In your search TextField:
 *   onTextEdited: searchDebounce.restart()
 */
Timer {
    id: root
    
    property int interval: 250
    repeat: false
    
    interval: root.interval
}
