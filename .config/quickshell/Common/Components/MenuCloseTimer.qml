import QtQuick

/**
 * Reusable component for creating menu close timers with proper cleanup.
 * Creates a Timer that closes the menu after a delay and destroys itself.
 * 
 * Usage:
 *   import "../Common/Components"
 * 
 *   Component {
 *       id: menuCloseTimerComponent
 *       MenuCloseTimer {}
 *   }
 * 
 *   // When showing a menu that should auto-close:
 *   const closeTimer = menuCloseTimerComponent.createObject(menuRoot, {
 *       menuRoot: menuRoot
 *   })
 */
Timer {
    property var menuRoot: null
    interval: 80
    repeat: false
    running: true
    
    onTriggered: {
        if (menuRoot && typeof menuRoot.close === 'function') {
            menuRoot.close()
        }
        destroy()
    }
    
    Component.onDestruction: {
        if (running) {
            stop()
        }
    }
}
