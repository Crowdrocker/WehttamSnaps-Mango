import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.Settings

Item {
    id: hyprlandAnimationsTab

    property var parentModal: null
    readonly property bool isHyprland: typeof CompositorService !== "undefined" && CompositorService.isHyprland

    property string configPath: Quickshell.env("HOME") + "/.config/hypr/hyprland/animations.lua"
    property var animationConfig: ({})
    property bool configLoaded: false

    Component.onCompleted: {
        loadAnimationConfig()
    }

    function loadAnimationConfig() {
        readConfigProcess.running = true
    }

    Process {
        id: readConfigProcess
        running: false
        command: ["sh", "-c", "if [ -f \"" + configPath + "\" ]; then cat \"" + configPath + "\"; else echo \"\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                hyprlandAnimationsTab.parseAnimationConfig(text || "")
                hyprlandAnimationsTab.configLoaded = true
            }
        }
    }

    function parseAnimationConfig(content) {
        var config = {}
        
        var animRe = /hl\.animation\(\s*\{([^}]+)\}\)/g
        var match
        while ((match = animRe.exec(content)) !== null) {
            var block = match[1]
            var leafMatch = block.match(/leaf\s*=\s*"(\w+)"/)
            if (!leafMatch) continue
            var leaf = leafMatch[1]
            
            var enabledMatch = block.match(/enabled\s*=\s*(true|false)/)
            var speedMatch = block.match(/speed\s*=\s*([\d.]+)/)
            var styleMatch = block.match(/style\s*=\s*"([^"]+)"/)
            
            var enabled = enabledMatch ? enabledMatch[1] === "true" : true
            var speed = speedMatch ? parseInt(speedMatch[1]) || 10 : 10
            var style = styleMatch ? styleMatch[1] : ""
            
            if (leaf === "windows" || leaf === "workspaces" || leaf === "fade") {
                config[leaf] = { enabled: enabled, speed: speed, style: style }
            }
        }
        
        animationConfig = config
        
        if (config.windows) {
            SettingsData.setHyprlandAnimationsWindowsEnabled(config.windows.enabled)
            SettingsData.setHyprlandAnimationsSpeed(config.windows.speed)
            if (config.windows.style) SettingsData.setHyprlandAnimationsWindowsStyle(config.windows.style)
        }
        if (config.workspaces) {
            SettingsData.setHyprlandAnimationsWorkspacesEnabled(config.workspaces.enabled)
            if (config.workspaces.style) SettingsData.setHyprlandAnimationsWorkspacesStyle(config.workspaces.style)
        }
        if (config.fade) {
            SettingsData.setHyprlandAnimationsFadeEnabled(config.fade.enabled)
            if (config.fade.style) SettingsData.setHyprlandAnimationsFadeStyle(config.fade.style)
        }
        
        parseBezierCurves(content)
    }

    function parseBezierCurves(content) {
        // Parse hl.curve("name", { type = "bezier", points = { {x1, y1}, {x2, y2} } })
        var curveRe = /hl\.curve\(\s*"(\w+)"\s*,\s*\{[^}]*type\s*=\s*"bezier"[^}]*points\s*=\s*\{\s*\{([\d.]+)\s*,\s*([\d.]+)\s*\}\s*,\s*\{([\d.]+)\s*,\s*([\d.]+)\s*\}\s*\}\s*\}\)/
        var curveMatch = content.match(curveRe)
        if (curveMatch) {
            bezierCanvas.setPoints(
                parseFloat(curveMatch[2]),
                parseFloat(curveMatch[3]),
                parseFloat(curveMatch[4]),
                parseFloat(curveMatch[5])
            )
            animationPreview.setPoints(
                parseFloat(curveMatch[2]),
                parseFloat(curveMatch[3]),
                parseFloat(curveMatch[4]),
                parseFloat(curveMatch[5])
            )
            currentCurveName = curveMatch[1]
        }
    }

    EHFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.implicitHeight + Theme.spacingL
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            // ════════════════════════════════════════════════════════════
            // CATEGORY 1: Bezier Curve Editor
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: curveEditorSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: curveEditorSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "timeline"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Animation Curve Editor"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Curve"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60
                        }

                        EHDropdown {
                            id: presetDropdown
                            width: 180
                            text: "Curve"
                            options: ["ease", "easeIn", "easeOut", "easeInOut", "linear", "default", "custom"]
                            currentValue: currentCurveName || "default"
                            onValueChanged: {
                                var presets = {
                                    "ease": [0.25, 0.1, 0.25, 1.0],
                                    "easeIn": [0.42, 0, 1.0, 1.0],
                                    "easeOut": [0, 0, 0.58, 1.0],
                                    "easeInOut": [0.42, 0, 0.58, 1.0],
                                    "linear": [0, 0, 1.0, 1.0],
                                    "default": [0.05, 0.7, 0.1, 1.0]
                                }
                                if (presets[value]) {
                                    bezierCanvas.setPoints(presets[value][0], presets[value][1], presets[value][2], presets[value][3])
                                    animationPreview.setPoints(presets[value][0], presets[value][1], presets[value][2], presets[value][3])
                                    currentCurveName = value
                                }
                            }
                        }

                        StyledText {
                            text: "Drag control points to customize"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    BezierCanvas {
                        id: bezierCanvas
                        x1: 0.05; y1: 0.7; x2: 0.1; y2: 1.0
                        width: parent.width
                        height: 280
                        onCurveChanged: function(nx1, ny1, nx2, ny2) {
                            animationPreview.setPoints(nx1, ny1, nx2, ny2)
                            animationPreview.start()
                            currentCurveName = "custom"
                        }
                        onDragEnd: function() {
                            animationPreview.start()
                        }
                    }

                    AnimationPreview {
                        id: animationPreview
                        x1: 0.05; y1: 0.7; x2: 0.1; y2: 1.0
                        width: parent.width
                        Component.onCompleted: start()
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXL
                        anchors.horizontalCenter: parent.horizontalCenter

                        Column {
                            spacing: Theme.spacingXS
                            StyledText { text: "Point 1 (X)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            EHTextField {
                                width: 80
                                text: bezierCanvas.x1.toFixed(3)
                                onTextChanged: {
                                    var val = parseFloat(text)
                                    if (!isNaN(val) && val >= 0 && val <= 1) {
                                        bezierCanvas.x1 = val
                                        animationPreview.setPoints(bezierCanvas.x1, bezierCanvas.y1, bezierCanvas.x2, bezierCanvas.y2)
                                    }
                                }
                            }
                        }

                        Column {
                            spacing: Theme.spacingXS
                            StyledText { text: "Point 1 (Y)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            EHTextField {
                                width: 80
                                text: bezierCanvas.y1.toFixed(3)
                                onTextChanged: {
                                    var val = parseFloat(text)
                                    if (!isNaN(val)) {
                                        bezierCanvas.y1 = val
                                        animationPreview.setPoints(bezierCanvas.x1, bezierCanvas.y1, bezierCanvas.x2, bezierCanvas.y2)
                                    }
                                }
                            }
                        }

                        Column {
                            spacing: Theme.spacingXS
                            StyledText { text: "Point 2 (X)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            EHTextField {
                                width: 80
                                text: bezierCanvas.x2.toFixed(3)
                                onTextChanged: {
                                    var val = parseFloat(text)
                                    if (!isNaN(val) && val >= 0 && val <= 1) {
                                        bezierCanvas.x2 = val
                                        animationPreview.setPoints(bezierCanvas.x1, bezierCanvas.y1, bezierCanvas.x2, bezierCanvas.y2)
                                    }
                                }
                            }
                        }

                        Column {
                            spacing: Theme.spacingXS
                            StyledText { text: "Point 2 (Y)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            EHTextField {
                                width: 80
                                text: bezierCanvas.y2.toFixed(3)
                                onTextChanged: {
                                    var val = parseFloat(text)
                                    if (!isNaN(val)) {
                                        bezierCanvas.y2 = val
                                        animationPreview.setPoints(bezierCanvas.x1, bezierCanvas.y1, bezierCanvas.x2, bezierCanvas.y2)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 2: Animation Settings
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: animationSettingsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: animationSettingsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "animation"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Animation Settings"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - 180 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText { text: "Window Animations"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Enable or disable window open/close animations"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }

                        EHToggle {
                            id: windowsAnimToggle
                            checked: SettingsData.hyprlandAnimationsWindowsEnabled !== false
                            onToggled: checked => {
                                SettingsData.setHyprlandAnimationsWindowsEnabled(checked)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: windowsAnimToggle.checked

                        Column {
                            width: parent.width - 180 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText { text: "Animation Speed"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Lower values = faster animations (deciseconds)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }

                        EHSlider {
                            width: 180
                            value: SettingsData.hyprlandAnimationsSpeed || 10
                            minimum: 1; maximum: 30; unit: "ds"
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainer
                            onSliderDragFinished: v => {
                                SettingsData.setHyprlandAnimationsSpeed(v)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: windowsAnimToggle.checked

                        Column {
                            width: parent.width - 180 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText { text: "Window Style"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Animation style for windows"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }

                        EHDropdown {
                            width: 180
                            text: "Style"
                            options: ["", "popin 87%", "popin 75%", "popin 100%"]
                            currentValue: SettingsData.hyprlandAnimationsWindowsStyle || ""
                            onValueChanged: {
                                SettingsData.setHyprlandAnimationsWindowsStyle(value)
                                if (configLoaded) hyprlandAnimationsTab.saveToConfig()
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - 180 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText { text: "Workspace Animations"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Enable or disable workspace switching animations"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }

                        EHToggle {
                            id: workspacesAnimToggle
                            checked: SettingsData.hyprlandAnimationsWorkspacesEnabled !== false
                            onToggled: checked => {
                                SettingsData.setHyprlandAnimationsWorkspacesEnabled(checked)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: workspacesAnimToggle.checked

                        Column {
                            width: parent.width - 180 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText { text: "Workspace Style"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Animation style for workspace switching"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }

                        EHDropdown {
                            width: 180
                            text: "Style"
                            options: ["", "fade", "slide", "slidevert"]
                            currentValue: SettingsData.hyprlandAnimationsWorkspacesStyle || ""
                            onValueChanged: {
                                SettingsData.setHyprlandAnimationsWorkspacesStyle(value)
                                if (configLoaded) hyprlandAnimationsTab.saveToConfig()
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: fadeAnimToggle.checked

                        Column {
                            width: parent.width - 180 - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText { text: "Fade Style"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Animation style for fading"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }

                        EHDropdown {
                            width: 180
                            text: "Style"
                            options: ["", "fade"]
                            currentValue: SettingsData.hyprlandAnimationsFadeStyle || ""
                            onValueChanged: {
                                SettingsData.setHyprlandAnimationsFadeStyle(value)
                                if (configLoaded) hyprlandAnimationsTab.saveToConfig()
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════
            // CATEGORY 3: Apply & Save
            // ════════════════════════════════════════════════════════════
            StyledRect {
                width: parent.width
                height: actionsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: actionsSection
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        EHIcon { name: "save"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Apply & Save"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    StyledText {
                        text: "Write changes to ~/.config/hypr/hyprland/animations.lua and apply to Hyprland"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Item {
                        width: parent.width
                        height: 48

                        Row {
                            anchors.fill: parent
                            spacing: Theme.spacingM
                            
                            StyledRect {
                                height: 32
                                radius: 8
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    EHIcon { name: "refresh"; size: 16; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                    StyledText { text: "Apply to Hyprland"; font.pixelSize: Theme.fontSizeSmall; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                }

                                StateLayer {
                                    stateColor: Theme.primary
                                    cornerRadius: 8
                                    onClicked: applyToHyprland()
                                }
                            }

                            StyledRect {
                                height: 32
                                radius: 8
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    EHIcon { name: "save"; size: 16; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                    StyledText { text: "Save to Config"; font.pixelSize: Theme.fontSizeSmall; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                }

                                StateLayer {
                                    stateColor: Theme.primary
                                    cornerRadius: 8
                                    onClicked: saveToConfig()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    property string currentCurveName: "custom"

    function applyToHyprland() {
        if (typeof CompositorService === "undefined" || !CompositorService.isHyprland) {
            if (typeof ToastService !== "undefined" && ToastService.showWarning) {
                ToastService.showWarning("Hyprland not detected")
            }
            return
        }
        
        var curveName = currentCurveName === "custom" ? "customCurve" : currentCurveName
        var speed = SettingsData.hyprlandAnimationsSpeed || 10
        
        // Define bezier curve
        var bezierDef = curveName + "," + bezierCanvas.x1.toFixed(3) + "," + bezierCanvas.y1.toFixed(3) + " " + bezierCanvas.x2.toFixed(3) + "," + bezierCanvas.y2.toFixed(3)
        
        // Apply bezier curve definition
        Quickshell.runSynced("hyprctl", ["keyword", "bezier", bezierDef])
        
        // Apply window animation
        var winEnabled = SettingsData.hyprlandAnimationsWindowsEnabled !== false ? "1" : "0"
        Quickshell.runSynced("hyprctl", ["keyword", "animation", "windows," + winEnabled + "," + speed + "," + curveName])
        
        // Apply workspace animation
        var wsEnabled = SettingsData.hyprlandAnimationsWorkspacesEnabled !== false ? "1" : "0"
        Quickshell.runSynced("hyprctl", ["keyword", "animation", "workspaces," + wsEnabled + "," + speed + "," + curveName])
        
        // Apply fade animation
        var fadeEnabled = SettingsData.hyprlandAnimationsFadeEnabled !== false ? "1" : "0"
        Quickshell.runSynced("hyprctl", ["keyword", "animation", "fade," + fadeEnabled + "," + speed + "," + curveName])
        
        if (typeof ToastService !== "undefined" && ToastService.showInfo) {
            ToastService.showInfo("Applied animations to Hyprland")
        }
    }

    function saveToConfig() {
        if (typeof CompositorService === "undefined" || !CompositorService.isHyprland) {
            if (typeof ToastService !== "undefined" && ToastService.showWarning) {
                ToastService.showWarning("Hyprland not detected")
            }
            return
        }
        
        var curveName = currentCurveName === "custom" ? "customCurve" : currentCurveName
        var speed = SettingsData.hyprlandAnimationsSpeed || 10
        
        var winEnabled = SettingsData.hyprlandAnimationsWindowsEnabled !== false ? "true" : "false"
        var wsEnabled = SettingsData.hyprlandAnimationsWorkspacesEnabled !== false ? "true" : "false"
        var fadeEnabled = SettingsData.hyprlandAnimationsFadeEnabled !== false ? "true" : "false"
        
        CompositorService.saveAnimationConfig(
            curveName,
            bezierCanvas.x1, bezierCanvas.y1,
            bezierCanvas.x2, bezierCanvas.y2,
            speed, winEnabled, wsEnabled, fadeEnabled,
            SettingsData.hyprlandAnimationsWindowsStyle,
            SettingsData.hyprlandAnimationsWorkspacesStyle,
            SettingsData.hyprlandAnimationsFadeStyle
        )
        
        applyToHyprland()
        
        if (typeof ToastService !== "undefined" && ToastService.showInfo) {
            ToastService.showInfo("Saved animations to config")
        }
    }
}