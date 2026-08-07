.pragma library

function escapeShellArg(str) {
    if (typeof str !== 'string') {
        return ''
    }
    
    return "'" + str.replace(/'/g, "'\\''") + "'"
}

function isValidPath(path) {
    if (typeof path !== 'string' || path.length === 0) {
        return false
    }
    
    if (path.indexOf('\0') !== -1) {
        return false
    }
    
    if (path.length > 4096) {
        return false
    }
    
    return true
}

function isValidCommand(command) {
    if (typeof command !== 'string' || command.length === 0) {
        return false
    }
    
    if (command.indexOf('\0') !== -1) {
        return false
    }
    
    if (command.length > 8192) {
        return false
    }
    
    return true
}

function buildSafeCdCommand(targetDir) {
    if (!isValidPath(targetDir)) {
        return null
    }
    
    const escapedDir = escapeShellArg(targetDir)
    return `cd ${escapedDir} 2>&1 && pwd || echo 'ERROR: cd: No such file or directory: ${escapedDir}'`
}

function buildSafeCommand(command) {
    if (!isValidCommand(command)) {
        return null
    }
    
    const escapedCommand = escapeShellArg(command)
    return `${escapedCommand}; pwd`
}


