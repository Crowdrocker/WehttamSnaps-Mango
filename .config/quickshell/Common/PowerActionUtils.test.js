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

const mockSessionService = {
    logout: () => { return true },
    suspend: () => { return true },
    hibernate: () => { return true },
    reboot: () => { return true },
    poweroff: () => { return true },
    hibernateSupported: true
}

const mockTheme = {
    error: "#ff0000",
    warning: "#ffaa00",
    primary: "#0000ff"
}

test("executePowerAction - logout", () => {
    let called = false
    mockSessionService.logout = () => { called = true }
    const result = PowerActionUtils.executePowerAction("logout", mockSessionService)
    assert(result === true, "Logout should succeed")
    assert(called === true, "Logout should be called")
})

test("executePowerAction - suspend", () => {
    let called = false
    mockSessionService.suspend = () => { called = true }
    const result = PowerActionUtils.executePowerAction("suspend", mockSessionService)
    assert(result === true, "Suspend should succeed")
    assert(called === true, "Suspend should be called")
})

test("executePowerAction - hibernate", () => {
    let called = false
    mockSessionService.hibernate = () => { called = true }
    const result = PowerActionUtils.executePowerAction("hibernate", mockSessionService)
    assert(result === true, "Hibernate should succeed")
    assert(called === true, "Hibernate should be called")
})

test("executePowerAction - hibernate not supported", () => {
    const serviceWithoutHibernate = { ...mockSessionService, hibernateSupported: false }
    const result = PowerActionUtils.executePowerAction("hibernate", serviceWithoutHibernate)
    assert(result === false, "Hibernate should fail when not supported")
})

test("executePowerAction - invalid action", () => {
    const result = PowerActionUtils.executePowerAction("invalid", mockSessionService)
    assert(result === false, "Invalid action should fail")
})

test("executePowerAction - null action", () => {
    const result = PowerActionUtils.executePowerAction(null, mockSessionService)
    assert(result === false, "Null action should fail")
})

test("executePowerAction - empty action", () => {
    const result = PowerActionUtils.executePowerAction("", mockSessionService)
    assert(result === false, "Empty action should fail")
})

test("executePowerAction - null service", () => {
    const result = PowerActionUtils.executePowerAction("logout", null)
    assert(result === false, "Null service should fail")
})

/**
 * Test getPowerActionColor
 */
test("getPowerActionColor - poweroff", () => {
    const color = PowerActionUtils.getPowerActionColor("poweroff", mockTheme)
    assert(color === mockTheme.error, "Poweroff should return error color")
})

test("getPowerActionColor - reboot", () => {
    const color = PowerActionUtils.getPowerActionColor("reboot", mockTheme)
    assert(color === mockTheme.warning, "Reboot should return warning color")
})

test("getPowerActionColor - logout", () => {
    const color = PowerActionUtils.getPowerActionColor("logout", mockTheme)
    assert(color === mockTheme.primary, "Logout should return primary color")
})

test("getPowerActionColor - invalid action", () => {
    const color = PowerActionUtils.getPowerActionColor("invalid", mockTheme)
    assert(color === mockTheme.primary, "Invalid action should return primary color")
})

test("getPowerActionColor - null theme", () => {
    const color = PowerActionUtils.getPowerActionColor("logout", null)
    assert(color === undefined, "Null theme should return undefined")
})

/**
 * Test isValidPowerAction
 */
test("isValidPowerAction - valid actions", () => {
    const validActions = ["logout", "suspend", "hibernate", "reboot", "poweroff"]
    for (const action of validActions) {
        assert(PowerActionUtils.isValidPowerAction(action), `${action} should be valid`)
    }
})

test("isValidPowerAction - invalid action", () => {
    assert(!PowerActionUtils.isValidPowerAction("invalid"), "Invalid action should fail")
    assert(!PowerActionUtils.isValidPowerAction(""), "Empty action should fail")
    assert(!PowerActionUtils.isValidPowerAction(null), "Null action should fail")
    assert(!PowerActionUtils.isValidPowerAction(123), "Non-string action should fail")
})

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { testResults }
}



