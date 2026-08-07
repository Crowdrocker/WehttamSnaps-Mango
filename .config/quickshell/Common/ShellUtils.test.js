const testResults = []

function test(name, fn) {
    try {
        fn()
        testResults.push({ name, passed: true })
    } catch (e) {
        testResults.push({ name, passed: false, error: e.message })
    }
}

function assert(condition, message) {
    if (!condition) {
        throw new Error(message || "Assertion failed")
    }
}

test("escapeShellArg - basic string", () => {
    const result = ShellUtils.escapeShellArg("test")
    assert(result === "'test'", "Basic string not escaped correctly")
})

test("escapeShellArg - string with single quotes", () => {
    const result = ShellUtils.escapeShellArg("test'string")
    assert(result === "'test'\\''string'", "Single quotes not escaped correctly")
})

test("escapeShellArg - string with multiple single quotes", () => {
    const result = ShellUtils.escapeShellArg("test'string'here")
    assert(result === "'test'\\''string'\\''here'", "Multiple single quotes not escaped correctly")
})

test("escapeShellArg - empty string", () => {
    const result = ShellUtils.escapeShellArg("")
    assert(result === "''", "Empty string not handled correctly")
})

test("escapeShellArg - non-string input", () => {
    const result = ShellUtils.escapeShellArg(null)
    assert(result === "", "Non-string input should return empty string")
})

test("escapeShellArg - special shell characters", () => {
    const dangerous = "test; rm -rf /"
    const result = ShellUtils.escapeShellArg(dangerous)
    assert(result.includes("'"), "Dangerous characters should be escaped")
})
test("isValidPath - valid path", () => {
    assert(ShellUtils.isValidPath("/home/user"), "Valid path should pass")
})

test("isValidPath - path with null byte", () => {
    const pathWithNull = "/home/user\0test"
    assert(!ShellUtils.isValidPath(pathWithNull), "Path with null byte should fail")
})

test("isValidPath - path too long", () => {
    const longPath = "a".repeat(5000)
    assert(!ShellUtils.isValidPath(longPath), "Path too long should fail")
})

test("isValidPath - empty string", () => {
    assert(!ShellUtils.isValidPath(""), "Empty path should fail")
})

test("isValidPath - non-string input", () => {
    assert(!ShellUtils.isValidPath(null), "Non-string input should fail")
    assert(!ShellUtils.isValidPath(123), "Non-string input should fail")
})

/**
 * Test isValidCommand with various inputs
 */
test("isValidCommand - valid command", () => {
    assert(ShellUtils.isValidCommand("ls -la"), "Valid command should pass")
})

test("isValidCommand - command with null byte", () => {
    const cmdWithNull = "ls\0; rm -rf /"
    assert(!ShellUtils.isValidCommand(cmdWithNull), "Command with null byte should fail")
})

test("isValidCommand - command too long", () => {
    const longCmd = "a".repeat(10000)
    assert(!ShellUtils.isValidCommand(longCmd), "Command too long should fail")
})

test("isValidCommand - empty string", () => {
    assert(!ShellUtils.isValidCommand(""), "Empty command should fail")
})

/**
 * Test buildSafeCdCommand
 */
test("buildSafeCdCommand - valid directory", () => {
    const result = ShellUtils.buildSafeCdCommand("/home/user")
    assert(result !== null, "Valid directory should return command")
    assert(result.includes("cd"), "Command should include cd")
})

test("buildSafeCdCommand - invalid path", () => {
    const result = ShellUtils.buildSafeCdCommand("/home/user\0test")
    assert(result === null, "Invalid path should return null")
})

test("buildSafeCdCommand - directory with spaces", () => {
    const result = ShellUtils.buildSafeCdCommand("/home/my user")
    assert(result !== null, "Directory with spaces should be handled")
    assert(result.includes("'"), "Should escape spaces properly")
})

/**
 * Test buildSafeCommand
 */
test("buildSafeCommand - valid command", () => {
    const result = ShellUtils.buildSafeCommand("ls -la")
    assert(result !== null, "Valid command should return command string")
})

test("buildSafeCommand - invalid command", () => {
    const result = ShellUtils.buildSafeCommand("")
    assert(result === null, "Invalid command should return null")
})

/**
 * Test command injection prevention
 */
test("Command injection - semicolon", () => {
    const malicious = "test; rm -rf /"
    const result = ShellUtils.buildSafeCommand(malicious)
    assert(result !== null, "Malicious command should be escaped, not rejected")
    assert(result.includes("'"), "Malicious command should be properly escaped")
})

test("Command injection - backticks", () => {
    const malicious = "test `rm -rf /`"
    const result = ShellUtils.buildSafeCommand(malicious)
    assert(result !== null, "Backticks should be escaped")
})

test("Command injection - dollar expansion", () => {
    const malicious = "test $(rm -rf /)"
    const result = ShellUtils.buildSafeCommand(malicious)
    assert(result !== null, "Dollar expansion should be escaped")
})

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { testResults }
}



