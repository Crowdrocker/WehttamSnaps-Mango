// BarPopupTrigger.js - Helper utilities for bars to trigger popups with correct positioning

/**
 * Get the screen-relative position of a widget/button
 * @param {Item} widget - The widget item to get position from
 * @returns {Object} Position object with x, y, width, height
 */
function getWidgetScreenPosition(widget) {
    if (!widget) {
        console.warn("[BarPopupTrigger] Widget is null")
        return { x: 0, y: 0, width: 80, height: 48 }
    }
    
    // Map widget position to screen coordinates
    const screenPos = widget.mapToItem(null, 0, 0)
    
    return {
        x: screenPos.x,
        y: screenPos.y,
        width: widget.width,
        height: widget.height
    }
}

/**
 * Determine which section of the bar the widget is in
 * @param {Item} widget - The widget item
 * @param {string} barPosition - Bar position: "top", "bottom", "left", "right"
 * @param {Object} screen - Screen object
 * @returns {string} Section name: "left", "center", "right" for horizontal bars; "top", "middle", "bottom" for vertical
 */
function getWidgetSection(widget, barPosition, screen) {
    if (!widget || !screen) {
        return ""
    }
    
    const pos = getWidgetScreenPosition(widget)
    const centerX = pos.x + pos.width / 2
    const centerY = pos.y + pos.height / 2
    
    if (barPosition === "left" || barPosition === "right") {
        // Vertical bar - determine top/middle/bottom
        const thirdHeight = screen.height / 3
        
        if (centerY < thirdHeight) {
            return "top"
        } else if (centerY < thirdHeight * 2) {
            return "middle"
        } else {
            return "bottom"
        }
    } else {
        // Horizontal bar - determine left/center/right
        const thirdWidth = screen.width / 3
        
        if (centerX < thirdWidth) {
            return "left"
        } else if (centerX < thirdWidth * 2) {
            return "center"
        } else {
            return "right"
        }
    }
}

/**
 * Trigger a popup from a widget with correct positioning
 * @param {Object} config - Configuration object
 * @param {Item} config.widget - The widget/button that triggers the popup
 * @param {Object} config.popup - The popup object (must have setTriggerPosition and toggle methods)
 * @param {string} config.barPosition - Bar position: "top", "bottom", "left", "right"
 * @param {Object} config.screen - Screen object
 * @param {number} config.barThickness - Bar thickness in pixels
 * @param {number} config.barSpacing - Bar spacing in pixels
 * @param {number} config.bottomGap - Bottom gap for bottom-positioned bars
 */
function triggerPopup(config) {
    const {
        widget,
        popup,
        barPosition,
        screen,
        barThickness,
        barSpacing,
        bottomGap
    } = config
    
    if (!widget) {
        console.warn("[BarPopupTrigger] No widget provided")
        return
    }
    
    if (!popup) {
        console.warn("[BarPopupTrigger] No popup provided")
        return
    }
    
    if (!screen) {
        console.warn("[BarPopupTrigger] No screen provided")
        return
    }
    
    // Get widget position
    const pos = getWidgetScreenPosition(widget)
    
    // Get widget section
    const section = getWidgetSection(widget, barPosition, screen)
    
    console.log(`[BarPopupTrigger] Triggering popup from widget:`)
    console.log(`  Position: (${pos.x}, ${pos.y})`)
    console.log(`  Size: ${pos.width}x${pos.height}`)
    console.log(`  Section: ${section}`)
    console.log(`  Bar: ${barPosition}, thickness: ${barThickness}`)
    
    // Set trigger position on popup
    if (popup.setTriggerPosition) {
        popup.setTriggerPosition(
            pos.x,
            pos.y,
            pos.width,
            pos.height,
            section,
            screen
        )
    } else {
        console.warn("[BarPopupTrigger] Popup does not have setTriggerPosition method")
    }
    
    // Also update bar configuration if popup supports it
    if (popup.barPosition !== undefined) popup.barPosition = barPosition
    if (popup.barThickness !== undefined) popup.barThickness = barThickness
    if (popup.barSpacing !== undefined) popup.barSpacing = barSpacing || 4
    if (popup.bottomGap !== undefined) popup.bottomGap = bottomGap || 0
    
    // Toggle the popup
    if (popup.toggle) {
        popup.toggle()
    } else if (popup.open) {
        popup.open()
    } else {
        console.warn("[BarPopupTrigger] Popup does not have toggle or open method")
    }
}

/**
 * Find a widget by ID in a bar's widget repeaters
 * @param {Object} bar - The bar object with leftSection, centerSection, rightSection
 * @param {string} widgetId - Widget ID to search for (e.g., "controlCenter", "appDrawer")
 * @returns {Item|null} The widget item or null if not found
 */
function findWidgetById(bar, widgetId) {
    if (!bar) {
        console.warn("[BarPopupTrigger] No bar provided to findWidgetById")
        return null
    }
    
    // Try to access widget sections
    const sections = []
    
    if (bar.leftSection) sections.push(bar.leftSection)
    if (bar.centerSection) sections.push(bar.centerSection)
    if (bar.rightSection) sections.push(bar.rightSection)
    
    // Search through each section
    for (const section of sections) {
        if (!section || !section.children) continue
        
        // Each section typically has a Repeater as its first child
        const repeater = section.children[0]
        if (!repeater || repeater.count === undefined) continue
        
        // Search through repeater items
        for (let i = 0; i < repeater.count; i++) {
            const loader = repeater.itemAt(i)
            if (!loader) continue
            
            // Check if this loader has the widgetId we're looking for
            if (loader.widgetId === widgetId && loader.item) {
                return loader.item
            }
        }
    }
    
    console.warn(`[BarPopupTrigger] Widget '${widgetId}' not found in bar`)
    return null
}

/**
 * Setup a widget to trigger a popup when clicked
 * This is a convenience function that can be called in Component.onCompleted
 * @param {Object} config - Configuration object
 * @param {Item} config.widget - The widget/button
 * @param {Object} config.popup - The popup object
 * @param {Object} config.bar - The bar object containing the widget
 */
function setupWidgetTrigger(config) {
    const { widget, popup, bar } = config
    
    if (!widget || !popup || !bar) {
        console.warn("[BarPopupTrigger] Invalid setupWidgetTrigger config")
        return
    }
    
    // Connect widget click to popup trigger
    if (widget.clicked) {
        widget.clicked.connect(function() {
            triggerPopup({
                widget: widget,
                popup: popup,
                barPosition: bar.barPosition || "bottom",
                screen: bar.screen,
                barThickness: bar.effectiveBarHeight || bar.barThickness || 48,
                barSpacing: bar.barSpacing || 4,
                bottomGap: bar.bottomGap || 0
            })
        })
    }
}
