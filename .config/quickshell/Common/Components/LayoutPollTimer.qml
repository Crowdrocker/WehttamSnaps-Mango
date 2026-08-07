import QtQuick

/**
 * Reusable polling timer for keyboard layout updates.
 * 
 * Note: Ideally this should be replaced with signal-based notifications
 * from XKB/Quickshell when available.
 * 
 * Usage:
 *   import "../Common/Components"
 * 
 *   LayoutPollTimer {
 *       id: updateTimer
 *       interval: 1000  // optional, defaults to 1000ms
 *       onTriggered: updateLayout()
 *   }
 */
Timer {
    id: root
    
    property int interval: 1000
    repeat: true
    running: true
    
    interval: root.interval
}
