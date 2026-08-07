function calculateRowsAndWidgets(controlCenterColumn, expandedSection, expandedWidgetIndex) {
    var rows = []
    var currentRow = []
    var currentWidth = 0
    var expandedRow = -1

    const widgets   = SettingsData.controlCenterWidgets || []
    const baseWidth = Math.max(1, controlCenterColumn.width || 0)
    // Use spacingM to match the Row spacing in WidgetGrid
    const spacing   = Theme.spacingM

    for (var i = 0; i < widgets.length; i++) {
        const widget = widgets[i]
        if (!widget)
            continue
        const forceFullRow = widget.id === "volumeMixer" || widget.id === "media" || widget.id === "weather"
            || ((widget.id === "wifi" || widget.id === "bluetooth") && (widget.width || 50) >= 100)
        const widgetWidth = forceFullRow ? 100 : (widget.width || 50)

        var itemWidth
        if (widgetWidth <= 25) {
            itemWidth = (baseWidth - spacing * 3) / 4
        } else if (widgetWidth <= 50) {
            itemWidth = (baseWidth - spacing) / 2
        } else if (widgetWidth <= 75) {
            itemWidth = (baseWidth - spacing * 2) * 0.75
        } else {
            itemWidth = baseWidth
        }
        // Slight visual inset so tiles don't feel edge-to-edge
        itemWidth = itemWidth * 0.95

        // Full-width widgets always get their own row
        if (forceFullRow) {
            if (currentRow.length > 0) {
                rows.push([...currentRow])
            }
            rows.push([widget])
            currentRow  = []
            currentWidth = 0

            // Row already pushed — expandedRow points AT this row (rows.length - 1)
            if (widget.id === expandedSection && expandedWidgetIndex === i) {
                expandedRow = rows.length - 1
            }
        } else if (currentRow.length > 0 && (currentWidth + spacing + itemWidth > baseWidth)) {
            rows.push([...currentRow])
            currentRow  = [widget]
            currentWidth = itemWidth

            // Row not yet pushed — rows.length is the index it will receive when pushed
            if (widget.id === expandedSection && expandedWidgetIndex === i) {
                expandedRow = rows.length
            }
        } else {
            currentRow.push(widget)
            currentWidth += (currentRow.length > 1 ? spacing : 0) + itemWidth

            // Row not yet pushed — rows.length is the index it will receive when pushed
            if (widget.id === expandedSection && expandedWidgetIndex === i) {
                expandedRow = rows.length
            }
        }
    }

    if (currentRow.length > 0) {
        rows.push(currentRow)
    }

    return { rows: rows, expandedRowIndex: expandedRow }
}
