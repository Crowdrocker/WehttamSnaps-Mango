import QtQuick

/**
 * Reusable timer for hover-triggered delayed actions (e.g., Dark Dash).
 * 
 * Usage:
 *   import "../Common/Components"
 * 
 *   HoverDelayTimer {
 *       id: hoverTimer
 *       interval: 2000  // optional, defaults to 2000ms
 *       onTriggered: root.openDarkDash()
 *   }
 * 
 *   // In your hoverable item:
 *   onEntered: hoverTimer.start()
 *   onExited: hoverTimer.stop()
 */
Timer {
    id: root
    
    property int interval: 2000
    repeat: false
    
    interval: root.interval
}
