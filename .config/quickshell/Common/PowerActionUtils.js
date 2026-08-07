.pragma library

/**
 * Power action utility functions
 * Centralizes power action handling to reduce code duplication
 */

/**
 * Executes a power action based on the action string
 * 
 * @param {string} action - The power action to execute ("logout", "suspend", "hibernate", "reboot", "poweroff")
 * @param {object} SessionService - The session service object
 * @returns {boolean} - True if action was executed, false if invalid
 */
function executePowerAction(action, SessionService) {
    if (!action || typeof action !== 'string' || !SessionService) {
        return false
    }
    
    switch (action) {
    case "logout":
        SessionService.logout()
        return true
    case "suspend":
        SessionService.suspend()
        return true
    case "hibernate":
        if (SessionService.hibernateSupported) {
            SessionService.hibernate()
            return true
        }
        return false
    case "reboot":
        SessionService.reboot()
        return true
    case "poweroff":
        SessionService.poweroff()
        return true
    default:
        return false
    }
}

/**
 * Gets the appropriate button color for a power action
 * 
 * @param {string} action - The power action
 * @param {object} Theme - The theme object
 * @returns {color} - The color for the action button
 */
function getPowerActionColor(action, Theme) {
    if (!action || typeof action !== 'string' || !Theme) {
        return Theme.primary
    }
    
    switch (action) {
    case "poweroff":
        return Theme.error
    case "reboot":
        return Theme.warning
    default:
        return Theme.primary
    }
}

/**
 * Validates if a power action is valid
 * 
 * @param {string} action - The power action to validate
 * @returns {boolean} - True if valid, false otherwise
 */
function isValidPowerAction(action) {
    if (!action || typeof action !== 'string') {
        return false
    }
    
    const validActions = ["logout", "suspend", "hibernate", "reboot", "poweroff"]
    return validActions.indexOf(action) !== -1
}


