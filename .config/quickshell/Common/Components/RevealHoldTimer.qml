import QtQuick

/**
 * Reusable timer for reveal/hold behavior (e.g., Dock and TopBar auto-hide).
 * Resets a sticky state after a hold duration.
 * 
 * Usage:
 *   import "../Common/Components"
 * 
 *   RevealHoldTimer {
 *       id: revealHold
 *       interval: 250  // optional, defaults to 250ms
 *       onTriggered: myRevealSticky = false
 *   }
 * 
 *   // To extend the hold:
 *   onMouseAreaEntered: revealHold.restart()
 */
Timer {
    id: root
    
    property int interval: 250
    repeat: false
    
    interval: root.interval
}
