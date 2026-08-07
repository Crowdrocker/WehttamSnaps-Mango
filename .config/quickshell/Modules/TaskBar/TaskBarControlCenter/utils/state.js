function setTriggerPosition(root, x, y, width, section, screen) {
    console.log(`[EHPopout] ${root.objectName} setTriggerPosition: (${x}, ${y}), width=${width}, section="${section}", screen=${screen ? screen.width + 'x' + screen.height : 'null'}`);
    // Always set trigger position since we use follow-trigger positioning
    root._calculatedTriggerX = x
    root._calculatedTriggerY = y
    root._triggerPositionSet = true
    root.triggerX = x
    root.triggerY = y
    root.triggerWidth = width
    root.triggerSection = section
    root.triggerScreen = screen
}

function openWithSection(root, section) {
    if (root.shouldBeVisible) {
        root.close()
    } else {
        root.expandedSection = section
        root.open()
    }
}

function toggleSection(root, section) {
    if (root.expandedSection === section) {
        root.expandedSection = ""
        root.expandedWidgetIndex = -1
    } else {
        root.expandedSection = section
    }
}