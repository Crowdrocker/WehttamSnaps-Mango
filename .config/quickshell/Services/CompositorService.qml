pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common

Singleton {
    id: root

    property bool isHyprland: false
    property bool isNiri: false
    property bool isMango: false
    property int mangoTagCount: 9
    property string compositor: "unknown"

    readonly property string hyprlandSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property string niriSocket: Quickshell.env("NIRI_SOCKET")
    readonly property bool useHyprlandFocusGrab: isHyprland && Quickshell.env("EH_HYPRLAND_EXCLUSIVE_FOCUS") !== "1"

    property bool useNiriSorting: isNiri && NiriService

    // Display scales from compositor
    property var displayScales: ({})

    // Get effective scale for a screen (compositor scale * user uiScaleRatio)
    function getDisplayScale(screenName) {
        const compositorScale = getScreenScaleForName(screenName)
        return compositorScale * Appearance.uiScaleRatio
    }

    // Get raw compositor scale for a screen name
    function getScreenScaleForName(screenName) {
        if (!screenName) {
            return 1
        }

        if (displayScales[screenName]) {
            return displayScales[screenName]
        }

        const screen = Quickshell.screens.find(s => s.name === screenName)
        return getScreenScale(screen) || 1
    }

    // Update display scales from screen
    function updateDisplayScales() {
        const scales = {}
        for (const screen of Quickshell.screens) {
            scales[screen.name] = getScreenScale(screen) || 1
        }
        displayScales = scales
    }

    property var sortedToplevels: {
        if (!ToplevelManager.toplevels || !ToplevelManager.toplevels.values) {
            return []
        }

        if (useNiriSorting) {
            return NiriService.sortToplevels(ToplevelManager.toplevels.values)
        }

        if (isHyprland) {
            const hyprlandToplevels = Array.from(Hyprland.toplevels.values)

            const sortedHyprland = hyprlandToplevels.sort((a, b) => {
                                                              if (a.monitor && b.monitor) {
                                                                  const monitorCompare = a.monitor.name.localeCompare(b.monitor.name)
                                                                  if (monitorCompare !== 0) {
                                                                      return monitorCompare
                                                                  }
                                                              }

                                                              if (a.workspace && b.workspace) {
                                                                  const workspaceCompare = a.workspace.id - b.workspace.id
                                                                  if (workspaceCompare !== 0) {
                                                                      return workspaceCompare
                                                                  }
                                                              }

                                                              if (a.lastIpcObject && b.lastIpcObject && a.lastIpcObject.at && b.lastIpcObject.at) {
                                                                  const aX = a.lastIpcObject.at[0]
                                                                  const bX = b.lastIpcObject.at[0]
                                                                  const aY = a.lastIpcObject.at[1]
                                                                  const bY = b.lastIpcObject.at[1]

                                                                  const xCompare = aX - bX
                                                                  if (Math.abs(xCompare) > 10) {
                                                                      return xCompare
                                                                  }
                                                                  return aY - bY
                                                              }

                                                              if (a.lastIpcObject && !b.lastIpcObject) {
                                                                  return -1
                                                              }
                                                              if (!a.lastIpcObject && b.lastIpcObject) {
                                                                  return 1
                                                              }

                                                              if (a.title && b.title) {
                                                                  return a.title.localeCompare(b.title)
                                                              }

                                                              return 0
                                                          })

            return sortedHyprland.map(hyprToplevel => hyprToplevel.wayland).filter(wayland => wayland !== null)
        }

        return ToplevelManager.toplevels.values
    }

    Component.onCompleted: {
        detectCompositor()
        Qt.callLater(updateDisplayScales)
    }

    function filterCurrentWorkspace(toplevels, screen) {
        if (useNiriSorting) {
            return NiriService.filterCurrentWorkspace(toplevels, screen)
        }
        if (isHyprland) {
            return filterHyprlandCurrentWorkspace(toplevels, screen)
        }
        return toplevels
    }

    function filterHyprlandCurrentWorkspace(toplevels, screenName) {
        if (!toplevels || toplevels.length === 0 || !Hyprland.toplevels) {
            return toplevels
        }

        let currentWorkspaceId = null
        const hyprlandToplevels = Array.from(Hyprland.toplevels.values)

        for (const hyprToplevel of hyprlandToplevels) {
            if (hyprToplevel.monitor && hyprToplevel.monitor.name === screenName && hyprToplevel.workspace) {
                if (hyprToplevel.activated) {
                    currentWorkspaceId = hyprToplevel.workspace.id
                    break
                }
                if (currentWorkspaceId === null) {
                    currentWorkspaceId = hyprToplevel.workspace.id
                }
            }
        }

        if (currentWorkspaceId === null && Hyprland.workspaces) {
            const workspaces = Array.from(Hyprland.workspaces.values)
            for (const workspace of workspaces) {
                if (workspace.monitor && workspace.monitor === screenName) {
                    if (Hyprland.focusedWorkspace && workspace.id === Hyprland.focusedWorkspace.id) {
                        currentWorkspaceId = workspace.id
                        break
                    }
                    if (currentWorkspaceId === null) {
                        currentWorkspaceId = workspace.id
                    }
                }
            }
        }

        if (currentWorkspaceId === null) {
            return toplevels
        }

        return toplevels.filter(toplevel => {
                                    for (const hyprToplevel of hyprlandToplevels) {
                                        if (hyprToplevel.wayland === toplevel) {
                                            return hyprToplevel.workspace && hyprToplevel.workspace.id === currentWorkspaceId
                                        }
                                    }
                                    return false
                                })
    }

    function detectCompositor() {
        if (hyprlandSignature && hyprlandSignature.length > 0) {
            isHyprland = true
            isNiri = false
            compositor = "hyprland"
            return
        }

        if (niriSocket && niriSocket.length > 0) {
            niriSocketCheck.running = true
        } else {
            isHyprland = false
            isNiri = false
            compositor = "unknown"
            tryMangoProbe()
        }
    }

    function tryMangoProbe() {
        if (isHyprland || isNiri)
            return
        mangoTagCountProbe.running = true
    }

    function getScreenScale(screen) {
        if (!screen)
            return 1

        if (isNiri) {
            return NiriService.getOutputScale(screen.name)
        }

        if (isMango) {
            return screen.devicePixelRatio || 1
        }

        if (isHyprland) {
            const hyprlandMonitor = Array.from(Hyprland.monitors.values).find(m => m.name === screen.name)
            if (hyprlandMonitor && hyprlandMonitor.scale !== undefined)
                return hyprlandMonitor.scale
        }

        return screen.devicePixelRatio || 1
    }

    function powerOffMonitors() {
        if (isNiri) {
            return NiriService.powerOffMonitors()
        }
        if (isHyprland) {
            return Hyprland.dispatch('hl.dsp.dpms({action = "off"})')
        }
    }

    function powerOnMonitors() {
        if (isNiri) {
            return NiriService.powerOnMonitors()
        }
        if (isHyprland) {
            return Hyprland.dispatch('hl.dsp.dpms({action = "on"})')
        }
    }

    function applyBlurSettings(blurSize, blurPasses) {
        if (!isHyprland) {
            return false
        }

        try {
            if (blurSize === 0) {
                hyprKeyword1.command = ["hyprctl", "keyword", "blur:enabled", "false"]
                hyprKeyword1.startDetached()
            } else {
                hyprKeyword1.command = ["hyprctl", "keyword", "blur:enabled", "true"]
                hyprKeyword1.startDetached()
                hyprKeyword2.command = ["hyprctl", "keyword", "blur:size", String(blurSize)]
                hyprKeyword2.startDetached()
                hyprKeyword3.command = ["hyprctl", "keyword", "blur:passes", String(blurPasses)]
                hyprKeyword3.startDetached()
                hyprKeyword4.command = ["hyprctl", "keyword", "blur:new_optimizations", "true"]
                hyprKeyword4.startDetached()
                hyprKeyword5.command = ["hyprctl", "keyword", "blur:ignore_opacity", "false"]
                hyprKeyword5.startDetached()
                hyprKeyword6.command = ["hyprctl", "keyword", "blur:xray", "false"]
                hyprKeyword6.startDetached()
                hyprKeyword7.command = ["hyprctl", "keyword", "blur:special", "false"]
                hyprKeyword7.startDetached()
            }
            return true
        } catch (error) {
            return false
        }
    }

    function applyHyprlandInputSetting(key, value) {
        if (!isHyprland) {
            return false
        }

        try {
            var luaV = luaValue(value)
            updateLuaSetting("input.lua", ["input"], key, luaV)
            return true
        } catch (error) {
            return false
        }
    }

    function applyHyprlandInputDeviceRotation(deviceName, rotation) {
        if (!isHyprland) {
            return false
        }

        try {
            var safeName = String(deviceName).replace(/[\\/&"]/g, "\\$&")
            var safeRotation = String(rotation).replace(/[\\/&"]/g, "\\$&")
            var homeDir = getHomeDir()
            var path = homeDir + "/.config/hypr/hyprland/input.lua"

            var cmd = "DEVICE_NAME='" + safeName + "' ROTATION='" + safeRotation + "' FILE='" + path + "' python3 - <<'PY'\n"
                + "import os, re\n"
                + "path = os.environ.get('FILE', '')\n"
                + "device = os.environ.get('DEVICE_NAME', '')\n"
                + "rotation = os.environ.get('ROTATION', '0')\n"
                + "if not device: raise SystemExit(0)\n"
                + "if not os.path.exists(path):\n"
                + "    d = os.path.dirname(path)\n"
                + "    if not os.path.exists(d): os.makedirs(d)\n"
                + "    with open(path, 'w', encoding='utf-8') as f:\n"
                + "        f.write('hl.config({\\n    input = {\\n    },\\n})\\n')\n"
                + "with open(path, 'r', encoding='utf-8') as f:\n"
                + "    lines = f.read().splitlines()\n"
                + "block_start = block_end = -1\n"
                + "depth = 0\n"
                + "for i, line in enumerate(lines):\n"
                + "    if 'hl.config' in line and '{' in line:\n"
                + "        block_start = i\n"
                + "    if block_start >= 0:\n"
                + "        depth += line.count('{') - line.count('}')\n"
                + "        if depth == 0 and i > block_start:\n"
                + "            block_end = i\n"
                + "            break\n"
                + "if block_start < 0: raise SystemExit(0)\n"
                + "input_start = input_end = -1\n"
                + "depth = 0\n"
                + "for i in range(block_start + 1, block_end):\n"
                + "    if re.match(r'^\\s*input\\s*=\\s*\\{', lines[i].strip()):\n"
                + "        input_start = i\n"
                + "        for j in range(i, block_end):\n"
                + "            depth += lines[j].count('{') - lines[j].count('}')\n"
                + "            if depth == 0:\n"
                + "                input_end = j\n"
                + "                break\n"
                + "        break\n"
                + "dev_header = 'device:' + device\n"
                + "dev_start = dev_end = -1\n"
                + "if input_start >= 0:\n"
                + "    depth = 0\n"
                + "    for i in range(input_start + 1, input_end):\n"
                + "        if re.match(r'^\\s*' + re.escape(dev_header) + r'\\s*=\\s*\\{', lines[i].strip()):\n"
                + "            dev_start = i\n"
                + "            for j in range(i, input_end):\n"
                + "                depth += lines[j].count('{') - lines[j].count('}')\n"
                + "                if depth == 0:\n"
                + "                    dev_end = j\n"
                + "                    break\n"
                + "            break\n"
                + "if dev_start < 0:\n"
                + "    insert_at = input_end if input_end >= 0 else block_end\n"
                + "    lines.insert(insert_at, '    ' + dev_header + ' = {')\n"
                + "    lines.insert(insert_at + 1, '        rotation = ' + rotation + ',')\n"
                + "    lines.insert(insert_at + 2, '    },')\n"
                + "else:\n"
                + "    pat = re.compile(r'^\\s*rotation\\s*=')\n"
                + "    replaced = False\n"
                + "    for i in range(dev_start + 1, dev_end):\n"
                + "        if pat.match(lines[i].strip()):\n"
                + "            lines[i] = '        rotation = ' + rotation + ','\n"
                + "            replaced = True\n"
                + "            break\n"
                + "    if not replaced:\n"
                + "        lines.insert(dev_end, '        rotation = ' + rotation + ',')\n"
                + "with open(path, 'w', encoding='utf-8') as f:\n"
                + "    f.write('\\n'.join(lines) + '\\n')\n"
                + "PY\n"
                + "&& hyprctl reload"
            inputUpdateProcess.command = ["sh", "-c", cmd]
            inputUpdateProcess.startDetached()
            return true
        } catch (error) {
            return false
        }
    }

    function applyHyprlandCursorSetting(key, value) {
        if (!isHyprland) {
            return false
        }

        try {
            var cmd = "hyprctl keyword cursor:" + key + " '" + value + "'"
            cursorUpdateProcess.command = ["sh", "-c", cmd]
            cursorUpdateProcess.startDetached()
            var luaV = luaValue(value)
            updateLuaSetting("cursor.lua", ["cursor"], key, luaV)
            return true
        } catch (error) {
            return false
        }
    }

    function updateBlurConfigSize(size) {
        if (!isHyprland) {
            return false
        }

        try {
            if (size === 0) {
                updateLuaSetting("decoration.lua", ["decoration", "blur"], "enabled", "false")
            } else {
                updateLuaSetting("decoration.lua", ["decoration", "blur"], "enabled", "true")
                updateLuaSetting("decoration.lua", ["decoration", "blur"], "size", String(size))
                updateLuaSetting("decoration.lua", ["decoration", "blur"], "new_optimizations", "true")
                updateLuaSetting("decoration.lua", ["decoration", "blur"], "ignore_opacity", "false")
                updateLuaSetting("decoration.lua", ["decoration", "blur"], "xray", "false")
                updateLuaSetting("decoration.lua", ["decoration", "blur"], "special", "false")
            }
            return true
        } catch (error) {
            return false
        }
    }

    function updateBlurConfigPasses(passes) {
        if (!isHyprland) {
            return false
        }

        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "passes", String(passes))
            return true
        } catch (error) {
            return false
        }
    }

    function applyBorderSize(size) {
        if (!isHyprland) {
            return false
        }

        try {
            var cmd = "hyprctl keyword general:border_size " + size
            borderUpdateProcess.command = ["sh", "-c", cmd]
            borderUpdateProcess.startDetached()
            updateLuaSetting("general.lua", ["general"], "border_size", String(size))
            return true
        } catch (error) {
            return false
        }
    }

    function applyBorderColors(hueShift, alpha) {
        if (!isHyprland) {
            return false
        }

        try {
            var primaryColor = typeof Theme !== 'undefined' ? Theme.primary : Qt.rgba(0.26, 0.65, 0.96, 1.0)

            var toHex = function(x) {
                var v = Math.round(Math.max(0, Math.min(255, x * 255)))
                return v.toString(16).padStart(2, '0')
            }

            var colorToHex = function(color, hueShift, alpha) {
                var r = color.r, g = color.g, b = color.b
                var max = Math.max(r, Math.max(g, b))
                var min = Math.min(r, Math.min(g, b))
                var h, s, l = (max + min) / 2
                var d = max - min

                if (d !== 0) {
                    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
                    if (max === r) {
                        h = ((g - b) / d + (g < b ? 6 : 0)) / 6
                    } else if (max === g) {
                        h = ((b - r) / d + 2) / 6
                    } else {
                        h = ((r - g) / d + 4) / 6
                    }
                } else {
                    h = s = 0
                }

                h = (h + hueShift / 360.0) % 1.0
                if (h < 0) h += 1.0

                var hue2rgb = function(p, q, t) {
                    if (t < 0) t += 1
                    if (t > 1) t -= 1
                    if (t < 1/6) return p + (q - p) * 6 * t
                    if (t < 1/2) return q
                    if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
                    return p
                }

                var q = l < 0.5 ? l * (1 + s) : l + s - l * s
                var p = 2 * l - q
                r = hue2rgb(p, q, h + 1/3)
                g = hue2rgb(p, q, h)
                b = hue2rgb(p, q, h - 1/3)

                var bgR = 0.0, bgG = 0.0, bgB = 0.0
                r = r * alpha + bgR * (1 - alpha)
                g = g * alpha + bgG * (1 - alpha)
                b = b * alpha + bgB * (1 - alpha)

                return toHex(r) + toHex(g) + toHex(b)
            }

            var activeHex = colorToHex(primaryColor, hueShift, alpha)

            var inactiveColor = Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, primaryColor.a)
            inactiveColor.r *= 0.5
            inactiveColor.g *= 0.5
            inactiveColor.b *= 0.5
            var inactiveHex = colorToHex(inactiveColor, hueShift, alpha)

            updateLuaColors(activeHex, inactiveHex)
            return true
        } catch (error) {
            return false
        }
    }

    function applyNiriBorderColors(hueShift, alpha, borderWidth) {
        if (!isNiri) {
            console.log("Niri border colors: not Niri compositor")
            return false
        }

        console.log("Niri border colors: applying with hueShift=" + hueShift + ", alpha=" + alpha + ", borderWidth=" + borderWidth)

        try {
            var primaryColor = typeof Theme !== 'undefined' ? Theme.primary : Qt.rgba(0.26, 0.65, 0.96, 1.0)
            var outlineColor = typeof Theme !== 'undefined' ? Theme.outline : Qt.rgba(0.5, 0.5, 0.5, 1.0)

            var r = primaryColor.r
            var g = primaryColor.g
            var b = primaryColor.b
            var max = Math.max(r, Math.max(g, b))
            var min = Math.min(r, Math.min(g, b))
            var h, s, l = (max + min) / 2
            var d = max - min

            if (d !== 0) {
                s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
                if (max === r) {
                    h = ((g - b) / d + (g < b ? 6 : 0)) / 6
                } else if (max === g) {
                    h = ((b - r) / d + 2) / 6
                } else {
                    h = ((r - g) / d + 4) / 6
                }
            } else {
                h = s = 0
            }

            h = (h + hueShift / 360.0) % 1.0
            if (h < 0) h += 1.0

            var hue2rgb = function(p, q, t) {
                if (t < 0) t += 1
                if (t > 1) t -= 1
                if (t < 1/6) return p + (q - p) * 6 * t
                if (t < 1/2) return q
                if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
                return p
            }

            var q = l < 0.5 ? l * (1 + s) : l + s - l * s
            var p = 2 * l - q
            r = hue2rgb(p, q, h + 1/3)
            g = hue2rgb(p, q, h)
            b = hue2rgb(p, q, h - 1/3)

            var bgR = 0.0
            var bgG = 0.0
            var bgB = 0.0
            r = r * alpha + bgR * (1 - alpha)
            g = g * alpha + bgG * (1 - alpha)
            b = b * alpha + bgB * (1 - alpha)

            var toHex = function(x) {
                var v = Math.round(Math.max(0, Math.min(255, x * 255)))
                return v.toString(16).padStart(2, '0')
            }
            var hexColor = toHex(r) + toHex(g) + toHex(b)
            var outlineHex = toHex(outlineColor.r) + toHex(outlineColor.g) + toHex(outlineColor.b)

            var effectiveBorderWidth = (typeof borderWidth !== 'undefined' && borderWidth !== null) ? borderWidth : (typeof SettingsData !== 'undefined' ? SettingsData.niriBorderWidth : 2)

            var kdlContent = "layout {\n"
            kdlContent += "    background-color \"transparent\"\n\n"
            kdlContent += "    focus-ring {\n"
            kdlContent += "        width " + effectiveBorderWidth + "\n"
            kdlContent += "        active-color   \"#" + hexColor + "\"\n"
            kdlContent += "        inactive-color \"#" + outlineHex + "\"\n"
            kdlContent += "        urgent-color   \"#ff0000\"\n"
            kdlContent += "    }\n\n"
            kdlContent += "    border {\n"
            kdlContent += "        on\n"
            kdlContent += "        width " + effectiveBorderWidth + "\n"
            kdlContent += "        active-color   \"#" + hexColor + "\"\n"
            kdlContent += "        inactive-color \"#" + outlineHex + "\"\n"
            kdlContent += "        urgent-color   \"#ff0000\"\n"
            kdlContent += "    }\n\n"
            kdlContent += "    shadow {\n"
            kdlContent += "        color \"#00000070\"\n"
            kdlContent += "    }\n\n"
            kdlContent += "    tab-indicator {\n"
            kdlContent += "        active-color   \"#" + hexColor + "\"\n"
            kdlContent += "        inactive-color \"#" + outlineHex + "\"\n"
            kdlContent += "        urgent-color   \"#ff0000\"\n"
            kdlContent += "    }\n\n"
            kdlContent += "    insert-hint {\n"
            kdlContent += "        color \"#" + hexColor + "80\"\n"
            kdlContent += "    }\n"
            kdlContent += "}\n"

            const homeDir = Quickshell.env("HOME") || Paths.stringify(StandardPaths.writableLocation(StandardPaths.HomeLocation));
            const niriEhDir = homeDir + "/.config/niri/eh";
            const colorsPath = niriEhDir + "/colors.kdl";

            var cmd = "mkdir -p \"" + niriEhDir + "\" && cat > \"" + colorsPath + "\" << 'EOF'\n"
            cmd += kdlContent + "\nEOF\n"
            cmd += " && niri msg reload"

            console.log("Niri border colors: executing command:", cmd)

            niriBorderColorProcess.command = ["sh", "-c", cmd]
            niriBorderColorProcess.startDetached()
            console.log("Niri border colors: command executed successfully")
            return true
        } catch (error) {
            console.error("Failed to apply Niri border colors:", error)
            return false
        }
    }

    Process {
        id: niriBorderColorProcess
    }

    function getHomeDir() {
        return Quickshell.env("HOME") || Paths.stringify(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    }

    function luaValue(v) {
        var s = String(v)
        if (s === "true" || s === "false") return s
        if (!isNaN(parseFloat(s)) && isFinite(s) && s.indexOf("0x") !== 0) return s
        return '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'
    }

    function updateLuaSetting(fileName, tablePath, key, value) {
        if (!isHyprland) return false
        try {
            var homeDir = getHomeDir()
            var path = homeDir + "/.config/hypr/hyprland/" + fileName
            var safeVal = String(value).replace(/\\/g, "\\\\").replace(/'/g, "'\\''")
            var safePath = path.replace(/'/g, "'\\''")
            var tablePathStr = JSON.stringify(tablePath)

            var cmd = "python3 - <<'PY'\n"
            + "import os, re, json\n"
            + "path = '" + safePath + "'\n"
            + "key = '" + String(key).replace(/'/g, "'\\''") + "'\n"
            + "value = '" + safeVal + "'\n"
            + "table_path = " + tablePathStr + "\n"
            + "if not os.path.exists(path):\n"
            + "    dir = os.path.dirname(path)\n"
            + "    if not os.path.exists(dir): os.makedirs(dir)\n"
            + "    with open(path, 'w', encoding='utf-8') as f:\n"
            + "        f.write('hl.config({\\n})\\n')\n"
            + "with open(path, 'r', encoding='utf-8') as f:\n"
            + "    lines = f.read().splitlines()\n"
            + "block_start = block_end = -1\n"
            + "depth = 0\n"
            + "for i, line in enumerate(lines):\n"
            + "    if 'hl.config' in line and '{' in line:\n"
            + "        block_start = i\n"
            + "    if block_start >= 0:\n"
            + "        depth += line.count('{') - line.count('}')\n"
            + "        if depth == 0 and block_start >= 0 and i > block_start:\n"
            + "            block_end = i\n"
            + "            break\n"
            + "if block_start < 0:\n"
            + "    lines.insert(0, 'hl.config({')\n"
            + "    lines.append('})')\n"
            + "    block_start = 0\n"
            + "    block_end = len(lines) - 1\n"
            + "start, end = block_start + 1, block_end\n"
            + "for section in table_path:\n"
            + "    found = False\n"
            + "    for i in range(start, end):\n"
            + "        m = re.match(r'^(\\s*)' + re.escape(section) + r'\\s*=\\s*\\{', lines[i].strip())\n"
            + "        if m:\n"
            + "            d = 0\n"
            + "            for j in range(i, end):\n"
            + "                d += lines[j].count('{') - lines[j].count('}')\n"
            + "                if d == 0:\n"
            + "                    start, end = i + 1, j\n"
            + "                    found = True\n"
            + "                    break\n"
            + "            break\n"
            + "    if not found:\n"
            + "        sec_idx = table_path.index(section)\n"
            + "        remaining = table_path[sec_idx:]\n"
            + "        for s_idx, s in enumerate(remaining):\n"
            + "            depth = sec_idx + s_idx\n"
            + "            lines.insert(end, '    ' * (depth + 1) + s + ' = {')\n"
            + "            end += 1\n"
            + "        lines.insert(end, '    ' * (len(table_path) + 1) + key + ' = ' + value + ',')\n"
            + "        end += 1\n"
            + "        for s_idx, s in enumerate(reversed(remaining)):\n"
            + "            depth = sec_idx + len(remaining) - s_idx - 1\n"
            + "            lines.insert(end, '    ' * (depth + 1) + '},')\n"
            + "            end += 1\n"
            + "        with open(path, 'w', encoding='utf-8') as f:\n"
            + "            f.write('\\n'.join(lines) + '\\n')\n"
            + "        raise SystemExit(0)\n"
            + "indent = '    ' * (len(table_path) + 1)\n"
            + "pat = re.compile(r'^\\s*' + re.escape(key) + r'\\s*=')\n"
            + "replaced = False\n"
            + "for i in range(start, end):\n"
            + "    if pat.match(lines[i].strip()):\n"
            + "        lines[i] = indent + key + ' = ' + value + ','\n"
            + "        replaced = True\n"
            + "        break\n"
            + "if not replaced:\n"
            + "    lines.insert(end, indent + key + ' = ' + value + ',')\n"
            + "with open(path, 'w', encoding='utf-8') as f:\n"
            + "    f.write('\\n'.join(lines) + '\\n')\n"
            + "PY\n"
            + "&& hyprctl reload"

            luaWriteProcess.command = ["sh", "-c", cmd]
            luaWriteProcess.startDetached()
            return true
        } catch (error) {
            return false
        }
    }

    function updateLuaColors(activeHex, inactiveHex) {
        if (!isHyprland) return false
        try {
            var homeDir = getHomeDir()
            var path = homeDir + "/.config/hypr/hyprland/colors.lua"
            var safePath = path.replace(/'/g, "'\\''")
            var safeActive = String(activeHex).replace(/'/g, "'\\''")
            var safeInactive = String(inactiveHex).replace(/'/g, "'\\''")

            var cmd = "python3 - <<'PY'\n"
            + "import os, re\n"
            + "path = '" + safePath + "'\n"
            + "active = '" + safeActive + "'\n"
            + "inactive = '" + safeInactive + "'\n"
            + "if not os.path.exists(path):\n"
            + "    dir = os.path.dirname(path)\n"
            + "    if not os.path.exists(dir): os.makedirs(dir)\n"
            + "    with open(path, 'w', encoding='utf-8') as f:\n"
            + "        f.write('hl.config({\\n    general = {\\n        col = {\\n        },\\n    },\\n})\\n')\n"
            + "with open(path, 'r', encoding='utf-8') as f:\n"
            + "    lines = f.read().splitlines()\n"
            + "block_start = block_end = -1\n"
            + "depth = 0\n"
            + "for i, line in enumerate(lines):\n"
            + "    if 'hl.config' in line and '{' in line:\n"
            + "        block_start = i\n"
            + "    if block_start >= 0:\n"
            + "        depth += line.count('{') - line.count('}')\n"
            + "        if depth == 0 and block_start >= 0 and i > block_start:\n"
            + "            block_end = i\n"
            + "            break\n"
            + "if block_start < 0:\n"
            + "    lines.insert(0, 'hl.config({')\n"
            + "    lines.append('})')\n"
            + "    block_start = 0\n"
            + "    block_end = len(lines) - 1\n"
            + "keys = {'active_border': '\\\"rgb(' + active + ')\\\"', 'inactive_border': '\\\"rgb(' + inactive + ')\\\"'}\n"
            + "col_start = col_end = -1\n"
            + "depth = 0\n"
            + "for i in range(block_start + 1, block_end):\n"
            + "    m = re.match(r'^\\s*col\\s*=\\s*\\{', lines[i].strip())\n"
            + "    if m:\n"
            + "        col_start = i\n"
            + "        for j in range(i, block_end):\n"
            + "            depth += lines[j].count('{') - lines[j].count('}')\n"
            + "            if depth == 0:\n"
            + "                col_end = j\n"
            + "                break\n"
            + "        break\n"
            + "if col_start < 0:\n"
            + "    lines.insert(block_end, '    col = {')\n"
            + "    col_start = block_end\n"
            + "    col_end = block_end + 1\n"
            + "    lines.insert(col_end + 1, '    },')\n"
            + "indent = '        '\n"
            + "for key, value in keys.items():\n"
            + "    pat = re.compile(r'^\\s*' + re.escape(key) + r'\\s*=')\n"
            + "    replaced = False\n"
            + "    for i in range(col_start + 1, col_end):\n"
            + "        if pat.match(lines[i].strip()):\n"
            + "            lines[i] = indent + key + ' = ' + value + ','\n"
            + "            replaced = True\n"
            + "            break\n"
            + "    if not replaced:\n"
            + "        lines.insert(col_end, indent + key + ' = ' + value + ',')\n"
            + "        col_end += 1\n"
            + "with open(path, 'w', encoding='utf-8') as f:\n"
            + "    f.write('\\n'.join(lines) + '\\n')\n"
            + "PY\n"
            + "&& hyprctl reload"

            luaColorsProcess.command = ["sh", "-c", cmd]
            luaColorsProcess.startDetached()
            return true
        } catch (error) {
            return false
        }
    }

    function applyNiriLayoutSettings(gaps, centerFocusedColumn, alwaysCenterSingleColumn, defaultColumnDisplay, defaultColumnWidth, struts, focusRingEnabled, focusRingWidth, borderEnabled, borderWidth, shadowEnabled, shadowSoftness, shadowSpread, shadowOffsetY, shadowDrawBehindWindow, tabIndicatorEnabled, tabIndicatorHideWhenSingle, tabIndicatorPosition, tabIndicatorWidth, tabIndicatorGap, insertHintEnabled, backgroundColorEnabled, emptyWorkspaceAboveFirst) {
        if (!isNiri) {
            console.log("Niri layout settings: Not running Niri, skipping apply")
            return false
        }

        console.log("Niri layout settings: Applying settings...")

        try {
            var kdlContent = "layout {\n"

            kdlContent += "    gaps " + gaps + "\n"
            kdlContent += "    center-focused-column \"" + centerFocusedColumn + "\"\n"

            if (alwaysCenterSingleColumn) {
                kdlContent += "    always-center-single-column\n"
            }

            kdlContent += "    default-column-display \"" + defaultColumnDisplay + "\"\n"
            kdlContent += "    default-column-width { proportion " + defaultColumnWidth + "; }\n"

            if (struts.top !== 0 || struts.bottom !== 0 || struts.left !== 0 || struts.right !== 0) {
                kdlContent += "    struts {\n"
                if (struts.top !== 0) kdlContent += "        top " + struts.top + "\n"
                if (struts.bottom !== 0) kdlContent += "        bottom " + struts.bottom + "\n"
                if (struts.left !== 0) kdlContent += "        left " + struts.left + "\n"
                if (struts.right !== 0) kdlContent += "        right " + struts.right + "\n"
                kdlContent += "    }\n"
            }

            kdlContent += "    focus-ring {\n"
            if (!focusRingEnabled) {
                kdlContent += "        off\n"
            }
            kdlContent += "        width " + focusRingWidth + "\n"
            kdlContent += "    }\n"

            kdlContent += "    border {\n"
            if (!borderEnabled) {
                kdlContent += "        off\n"
            }
            kdlContent += "        width " + borderWidth + "\n"
            kdlContent += "    }\n"

            kdlContent += "    shadow {\n"
            if (!shadowEnabled) {
                kdlContent += "        off\n"
            } else {
                kdlContent += "        on\n"
                kdlContent += "        softness " + shadowSoftness + "\n"
                kdlContent += "        spread " + shadowSpread + "\n"
                kdlContent += "        offset x=0 y=" + shadowOffsetY + "\n"
                if (shadowDrawBehindWindow) {
                    kdlContent += "        draw-behind-window true\n"
                }
            }
            kdlContent += "    }\n"

            kdlContent += "    tab-indicator {\n"
            if (!tabIndicatorEnabled) {
                kdlContent += "        off\n"
            } else {
                if (tabIndicatorHideWhenSingle) {
                    kdlContent += "        hide-when-single-tab\n"
                }
                kdlContent += "        position \"" + tabIndicatorPosition + "\"\n"
                kdlContent += "        width " + tabIndicatorWidth + "\n"
                kdlContent += "        gap " + tabIndicatorGap + "\n"
            }
            kdlContent += "    }\n"

            kdlContent += "    insert-hint {\n"
            if (!insertHintEnabled) {
                kdlContent += "        off\n"
            }
            kdlContent += "    }\n"

            if (emptyWorkspaceAboveFirst) {
                kdlContent += "    empty-workspace-above-first\n"
            }

            kdlContent += "}\n"

            const homeDir = Quickshell.env("HOME") || Paths.stringify(StandardPaths.writableLocation(StandardPaths.HomeLocation));
            const niriEhDir = homeDir + "/.config/niri/eh";
            const layoutsPath = niriEhDir + "/layouts.kdl";

            var cmd = "mkdir -p \"" + niriEhDir + "\" && cat > \"" + layoutsPath + "\" << 'EOF'\n"
            cmd += kdlContent + "\nEOF\n"
            cmd += " && niri msg reload"

            console.log("Niri layout settings: executing command:", cmd)

            niriLayoutProcess.command = ["sh", "-c", cmd]
            niriLayoutProcess.startDetached()
            console.log("Niri layout settings: command executed successfully")
            return true
        } catch (error) {
            console.error("Failed to apply Niri layout settings:", error)
            return false
        }
    }

    Process {
        id: niriLayoutProcess
    }

    function reloadHyprlandConfig() {
        if (!isHyprland) {
            return false
        }

        Quickshell.execDetached(["hyprctl", "reload"])
        return true
    }

    Process {
        id: niriSocketCheck
        command: ["test", "-S", root.niriSocket]

        onExited: exitCode => {
            if (exitCode === 0) {
                root.isNiri = true
                root.isHyprland = false
                root.compositor = "niri"
            } else {
                root.isHyprland = false
                root.isNiri = false
                root.compositor = "unknown"
            }
            if (!root.isHyprland && !root.isNiri)
                root.tryMangoProbe()
        }
    }

    Process {
        id: mangoTagCountProbe
        command: ["mmsg", "get", "version"]

        stdout: StdioCollector {
            id: mangoTagCountStdout

            onStreamFinished: {
                if (root.isHyprland || root.isNiri)
                    return
                if (mangoTagCountStdout.text && mangoTagCountStdout.text.trim().length > 0) {
                    try {
                        const data = JSON.parse(mangoTagCountStdout.text.trim())
                        if (data.version) {
                            root.isMango = true
                            root.compositor = "mango"
                        }
                    } catch (e) {}
                }
            }
        }
    }

    function applyDecorationRounding(rounding) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration"], "rounding", String(rounding))
            return true
        } catch (error) { return false }
    }

    function applyDecorationRoundingPower(power) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration"], "rounding_power", String(power))
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurEnabled(enabled) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "enabled", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurXray(xray) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "xray", xray ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurSpecial(special) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "special", special ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurNewOptimizations(optimizations) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "new_optimizations", optimizations ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurIgnoreOpacity(ignore) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "ignore_opacity", ignore ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurSize(size) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "size", String(size))
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurPasses(passes) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "passes", String(passes))
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurBrightness(brightness) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "brightness", String(brightness))
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurNoise(noise) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "noise", String(noise))
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurContrast(contrast) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "contrast", String(contrast))
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurVibrancy(vibrancy) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "vibrancy", String(vibrancy))
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurVibrancyDarkness(vibrancyDarkness) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "vibrancy_darkness", String(vibrancyDarkness))
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurBrightnessEnabled(enabled) {
        if (!isHyprland) return false
        try { return true } catch (error) { return false }
    }

    function applyDecorationBlurContrastEnabled(enabled) {
        if (!isHyprland) return false
        try { return true } catch (error) { return false }
    }

    function applyDecorationBlurPopups(popups) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "popups", popups ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurPopupsIgnorealpha(alpha) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "popups_ignorealpha", String(alpha))
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurInputMethods(inputMethods) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "input_methods", inputMethods ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyDecorationBlurInputMethodsIgnorealpha(alpha) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "blur"], "input_methods_ignorealpha", String(alpha))
            return true
        } catch (error) { return false }
    }

    function applyDecorationShadowEnabled(enabled) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "shadow"], "enabled", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyDecorationShadowIgnoreWindow(ignore) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "shadow"], "ignore_window", ignore ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyDecorationShadowRange(range) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "shadow"], "range", String(range))
            return true
        } catch (error) { return false }
    }

    function applyDecorationShadowRenderPower(power) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "shadow"], "render_power", String(power))
            return true
        } catch (error) { return false }
    }

    function applyDecorationShadowColor(color) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration", "shadow"], "color", luaValue(color))
            return true
        } catch (error) { return false }
    }

    function applyDecorationDimInactive(inactive) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration"], "dim_inactive", inactive ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyDecorationDimStrength(strength) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration"], "dim_strength", String(strength))
            return true
        } catch (error) { return false }
    }

    function applyDecorationDimSpecial(special) {
        if (!isHyprland) return false
        try {
            updateLuaSetting("decoration.lua", ["decoration"], "dim_special", String(special))
            return true
        } catch (error) { return false }
    }

    // ── Lua: updateRenderSetting ────────────────────────────────────────────
    function updateRenderSetting(key, value) {
        console.log("[Render] updateRenderSetting called with key:", key, "value:", value)
        if (!isHyprland) {
            console.log("[Render] Not Hyprland, returning false")
            return false
        }

        try {
            console.log("[Render] Calling updateLuaSetting...")
            updateLuaSetting("render.lua", ["render"], key, value)
            console.log("[Render] Done")
            return true
        } catch (error) {
            console.log("[Render] Catch error:", error)
            return false
        }
    }

    function updateColorsSetting(sectionPath, key, value) {
        if (!isHyprland) {
            return false
        }

        try {
            var sections = sectionPath.split('/')
            updateLuaSetting("general.lua", sections, key, value)
            return true
        } catch (error) {
            return false
        }
    }

    function saveAnimationConfig(curveName, x1, y1, x2, y2, speed, winEnabled, wsEnabled, fadeEnabled, winStyle, wsStyle, fadeStyle) {
        if (!isHyprland) return false
        try {
            var homeDir = getHomeDir()
            var configPath = homeDir + "/.config/hypr/hyprland/animations.lua"

            var winStyleStr = winStyle ? ", style = \"" + winStyle + "\"" : ""
            var wsStyleStr = wsStyle ? ", style = \"" + wsStyle + "\"" : ""
            var fadeStyleStr = fadeStyle ? ", style = \"" + fadeStyle + "\"" : ""

            var content = "hl.config({\n"
            content += "    animations = {\n"
            content += "        enabled = true,\n"
            content += "    },\n"
            content += "})\n"
            content += "\n"
            content += "hl.curve(\"" + curveName + "\", { type = \"bezier\", points = { {" + x1.toFixed(3) + ", " + y1.toFixed(3) + "}, {" + x2.toFixed(3) + ", " + y2.toFixed(3) + "} } })\n"
            content += "\n"
            content += "hl.animation({ leaf = \"windows\",    enabled = " + winEnabled + ", speed = " + speed + ", bezier = \"" + curveName + "\"" + winStyleStr + " })\n"
            content += "hl.animation({ leaf = \"workspaces\", enabled = " + wsEnabled + ", speed = " + speed + ", bezier = \"" + curveName + "\"" + wsStyleStr + " })\n"
            content += "hl.animation({ leaf = \"fade\",       enabled = " + fadeEnabled + ", speed = " + speed + ", bezier = \"" + curveName + "\"" + fadeStyleStr + " })\n"

            var safePath = configPath.replace(/'/g, "'\\''")
            var cmd = "mkdir -p '" + safePath.replace(/\/[^/]*$/, "") + "' && cat > '" + safePath + "' << 'HEREDOC_END'\n"
            cmd += content
            cmd += "\nHEREDOC_END\n"
            cmd += " && hyprctl reload"

            luaAnimationWriteProcess.command = ["sh", "-c", cmd]
            luaAnimationWriteProcess.startDetached()
            return true
        } catch (error) {
            return false
        }
    }

    // Render functions
    function applyRenderNewScheduling(scheduling) {
        console.log("[Render] applyRenderNewScheduling called:", scheduling, "isHyprland:", isHyprland)
        if (!isHyprland) { console.log("[Render] Not Hyprland, returning"); return false }
        try { 
            var result = updateRenderSetting("new_render_scheduling", scheduling ? "true" : "false")
            console.log("[Render] updateRenderSetting result:", result)
            return result
        }
        catch (error) { console.log("[Render] Error:", error); return false }
    }

    function applyRenderCmFsPassthrough(passthrough) {
        console.log("[Render] applyRenderCmFsPassthrough called:", passthrough)
        if (!isHyprland) { return false }
        try { return updateRenderSetting("cm_fs_passthrough", passthrough) }
        catch (error) { return false }
    }

    function applyRenderCmEnabled(enabled) {
        console.log("[Render] applyRenderCmEnabled called:", enabled)
        if (!isHyprland) { return false }
        try { return updateRenderSetting("cm_enabled", enabled ? "true" : "false") }
        catch (error) { return false }
    }

    function applyRenderSendContentType(send) {
        console.log("[Render] applyRenderSendContentType called:", send)
        if (!isHyprland) { return false }
        try { return updateRenderSetting("send_content_type", send ? "true" : "false") }
        catch (error) { return false }
    }

    function applyRenderCmAutoHdr(hdr) {
        console.log("[Render] applyRenderCmAutoHdr called:", hdr)
        if (!isHyprland) { return false }
        try { return updateRenderSetting("cm_auto_hdr", hdr ? "1" : "0") }
        catch (error) { return false }
    }

    function applyRenderDirectScanout(scanout) {
        if (!isHyprland) { return false }
        try { return updateRenderSetting("direct_scanout", scanout) }
        catch (error) { return false }
    }

    function applyRenderExpandUndersizedTextures(enabled) {
        if (!isHyprland) { return false }
        try { return updateRenderSetting("expand_undersized_textures", enabled ? "true" : "false") }
        catch (error) { return false }
    }

    // Snap functions
    function applyHyprlandSnapEnabled(enabled) {
        if (!isHyprland) { return false }
        try { return updateColorsSetting("general/snap", "enabled", enabled ? "true" : "false") }
        catch (error) { return false }
    }

    function applyHyprlandSnapWindowGap(value) {
        if (!isHyprland) { return false }
        try { return updateColorsSetting("general/snap", "window_gap", value) }
        catch (error) { return false }
    }

    function applyHyprlandSnapMonitorGap(value) {
        if (!isHyprland) { return false }
        try { return updateColorsSetting("general/snap", "monitor_gap", value) }
        catch (error) { return false }
    }

    function applyHyprlandSnapBorderOverlap(enabled) {
        if (!isHyprland) { return false }
        try { return updateColorsSetting("general/snap", "border_overlap", enabled ? "true" : "false") }
        catch (error) { return false }
    }

    function applyHyprlandSnapRespectGaps(enabled) {
        if (!isHyprland) { return false }
        try { return updateColorsSetting("general/snap", "respect_gaps", enabled ? "true" : "false") }
        catch (error) { return false }
    }

    // General functions
    function applyHyprlandGeneralGapsIn(value) {
        if (!isHyprland) { return false }
        try { return updateColorsSetting("general", "gaps_in", value) }
        catch (error) { return false }
    }

    function applyHyprlandGeneralGapsOut(value) {
        if (!isHyprland) { return false }
        try { return updateColorsSetting("general", "gaps_out", value) }
        catch (error) { return false }
    }

    function applyHyprlandGeneralGapsWorkspaces(value) {
        if (!isHyprland) { return false }
        try { return updateColorsSetting("general", "gaps_workspaces", value) }
        catch (error) { return false }
    }

    function applyHyprlandGeneralBorderSize(value) {
        if (!isHyprland) { return false }
        try { return updateColorsSetting("general", "border_size", value) }
        catch (error) { return false }
    }

    function applyHyprlandGeneralResizeOnBorder(enabled) {
        if (!isHyprland) { return false }
        try { return updateColorsSetting("general", "resize_on_border", enabled ? "true" : "false") }
        catch (error) { return false }
    }

    function applyHyprlandGeneralNoFocusFallback(enabled) {
        if (!isHyprland) { return false }
        try { return updateColorsSetting("general", "no_focus_fallback", enabled ? "true" : "false") }
        catch (error) { return false }
    }

    function applyHyprlandGeneralAllowTearing(enabled) {
        if (!isHyprland) { return false }
        try { return updateColorsSetting("general", "allow_tearing", enabled ? "true" : "false") }
        catch (error) { return false }
    }

    function applyHyprlandGeneralLayout(layout) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword general:layout " + layout
            hyprKeyword1.command = ["sh", "-c", cmd]
            hyprKeyword1.startDetached()
            updateLuaSetting("general.lua", ["general"], "layout", luaValue(layout))
            return true
        } catch (error) { return false }
    }

    // Master layout functions
    function applyHyprlandMasterAllowSmallSplit(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword master:allow_small_split " + (enabled ? "true" : "false")
            masterAllowSmallSplitProcess.command = ["sh", "-c", cmd]
            masterAllowSmallSplitProcess.startDetached()
            updateLuaSetting("layout.lua", ["master"], "allow_small_split", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandMasterSpecialScaleFactor(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword master:special_scale_factor " + value
            masterSpecialScaleFactorProcess.command = ["sh", "-c", cmd]
            masterSpecialScaleFactorProcess.startDetached()
            updateLuaSetting("layout.lua", ["master"], "special_scale_factor", String(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandMasterMfact(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword master:mfact " + value
            masterMfactProcess.command = ["sh", "-c", cmd]
            masterMfactProcess.startDetached()
            updateLuaSetting("layout.lua", ["master"], "mfact", String(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandMasterNewStatus(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword master:new_status " + value
            masterNewStatusProcess.command = ["sh", "-c", cmd]
            masterNewStatusProcess.startDetached()
            updateLuaSetting("layout.lua", ["master"], "new_status", luaValue(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandMasterNewOnTop(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword master:new_on_top " + (enabled ? "true" : "false")
            masterNewOnTopProcess.command = ["sh", "-c", cmd]
            masterNewOnTopProcess.startDetached()
            updateLuaSetting("layout.lua", ["master"], "new_on_top", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandMasterNewOnActive(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword master:new_on_active " + value
            masterNewOnActiveProcess.command = ["sh", "-c", cmd]
            masterNewOnActiveProcess.startDetached()
            updateLuaSetting("layout.lua", ["master"], "new_on_active", luaValue(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandMasterOrientation(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword master:orientation " + value
            masterOrientationProcess.command = ["sh", "-c", cmd]
            masterOrientationProcess.startDetached()
            updateLuaSetting("layout.lua", ["master"], "orientation", luaValue(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandMasterSlaveCountForCenterMaster(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword master:slave_count_for_center_master " + value
            masterSlaveCountProcess.command = ["sh", "-c", cmd]
            masterSlaveCountProcess.startDetached()
            updateLuaSetting("layout.lua", ["master"], "slave_count_for_center_master", String(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandMasterCenterMasterFallback(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword master:center_master_fallback " + value
            masterCenterMasterFallbackProcess.command = ["sh", "-c", cmd]
            masterCenterMasterFallbackProcess.startDetached()
            updateLuaSetting("layout.lua", ["master"], "center_master_fallback", luaValue(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandMasterSmartResizing(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword master:smart_resizing " + (enabled ? "true" : "false")
            masterSmartResizingProcess.command = ["sh", "-c", cmd]
            masterSmartResizingProcess.startDetached()
            updateLuaSetting("layout.lua", ["master"], "smart_resizing", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandMasterDropAtCursor(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword master:drop_at_cursor " + (enabled ? "true" : "false")
            masterDropAtCursorProcess.command = ["sh", "-c", cmd]
            masterDropAtCursorProcess.startDetached()
            updateLuaSetting("layout.lua", ["master"], "drop_at_cursor", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandMasterAlwaysKeepPosition(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword master:always_keep_position " + (enabled ? "true" : "false")
            masterAlwaysKeepPositionProcess.command = ["sh", "-c", cmd]
            masterAlwaysKeepPositionProcess.startDetached()
            updateLuaSetting("layout.lua", ["master"], "always_keep_position", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    // Scrolling layout functions
    function applyHyprlandScrollingFullscreenOnOneColumn(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword scrolling:fullscreen_on_one_column " + (enabled ? "true" : "false")
            scrollingFullscreenProcess.command = ["sh", "-c", cmd]
            scrollingFullscreenProcess.startDetached()
            updateLuaSetting("layout.lua", ["scrolling"], "fullscreen_on_one_column", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandScrollingColumnWidth(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword scrolling:column_width " + value
            scrollingColumnWidthProcess.command = ["sh", "-c", cmd]
            scrollingColumnWidthProcess.startDetached()
            updateLuaSetting("layout.lua", ["scrolling"], "column_width", String(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandScrollingFocusFitMethod(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword scrolling:focus_fit_method " + value
            scrollingFocusFitMethodProcess.command = ["sh", "-c", cmd]
            scrollingFocusFitMethodProcess.startDetached()
            updateLuaSetting("layout.lua", ["scrolling"], "focus_fit_method", String(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandScrollingFollowFocus(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword scrolling:follow_focus " + (enabled ? "true" : "false")
            scrollingFollowFocusProcess.command = ["sh", "-c", cmd]
            scrollingFollowFocusProcess.startDetached()
            updateLuaSetting("layout.lua", ["scrolling"], "follow_focus", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandScrollingFollowMinVisible(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword scrolling:follow_min_visible " + value
            scrollingFollowMinVisibleProcess.command = ["sh", "-c", cmd]
            scrollingFollowMinVisibleProcess.startDetached()
            updateLuaSetting("layout.lua", ["scrolling"], "follow_min_visible", String(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandScrollingExplicitColumnWidths(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword scrolling:explicit_column_widths " + value
            scrollingExplicitColumnWidthsProcess.command = ["sh", "-c", cmd]
            scrollingExplicitColumnWidthsProcess.startDetached()
            updateLuaSetting("layout.lua", ["scrolling"], "explicit_column_widths", luaValue(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandScrollingWrapFocus(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword scrolling:wrap_focus " + (enabled ? "true" : "false")
            scrollingWrapFocusProcess.command = ["sh", "-c", cmd]
            scrollingWrapFocusProcess.startDetached()
            updateLuaSetting("layout.lua", ["scrolling"], "wrap_focus", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandScrollingWrapSwapcol(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword scrolling:wrap_swapcol " + (enabled ? "true" : "false")
            scrollingWrapSwapcolProcess.command = ["sh", "-c", cmd]
            scrollingWrapSwapcolProcess.startDetached()
            updateLuaSetting("layout.lua", ["scrolling"], "wrap_swapcol", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandScrollingDirection(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword scrolling:direction " + value
            scrollingDirectionProcess.command = ["sh", "-c", cmd]
            scrollingDirectionProcess.startDetached()
            updateLuaSetting("layout.lua", ["scrolling"], "direction", luaValue(value))
            return true
        } catch (error) { return false }
    }

    // Groupbar functions
    function applyHyprlandGroupbarEnabled(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword group:groupbar:enabled " + (enabled ? "true" : "false")
            groupbarEnabledProcess.command = ["sh", "-c", cmd]
            groupbarEnabledProcess.startDetached()
            updateLuaSetting("group.lua", ["group", "groupbar"], "enabled", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandGroupbarColActive(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword group:groupbar:col.active " + value
            groupbarColActiveProcess.command = ["sh", "-c", cmd]
            groupbarColActiveProcess.startDetached()
            updateLuaSetting("group.lua", ["group", "groupbar"], "col.active", luaValue(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandGroupbarColInactive(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword group:groupbar:col.inactive " + value
            groupbarColInactiveProcess.command = ["sh", "-c", cmd]
            groupbarColInactiveProcess.startDetached()
            updateLuaSetting("group.lua", ["group", "groupbar"], "col.inactive", luaValue(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandGroupbarHeight(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword group:groupbar:height " + value
            groupbarHeightProcess.command = ["sh", "-c", cmd]
            groupbarHeightProcess.startDetached()
            updateLuaSetting("group.lua", ["group", "groupbar"], "height", String(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandGroupbarPriority(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword group:groupbar:priority " + value
            groupbarPriorityProcess.command = ["sh", "-c", cmd]
            groupbarPriorityProcess.startDetached()
            updateLuaSetting("group.lua", ["group", "groupbar"], "priority", String(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandGroupbarRenderTitles(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword group:groupbar:render_titles " + (enabled ? "true" : "false")
            groupbarRenderTitlesProcess.command = ["sh", "-c", cmd]
            groupbarRenderTitlesProcess.startDetached()
            updateLuaSetting("group.lua", ["group", "groupbar"], "render_titles", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandGroupbarFontFamily(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword group:groupbar:font_family " + value
            groupbarFontFamilyProcess.command = ["sh", "-c", cmd]
            groupbarFontFamilyProcess.startDetached()
            updateLuaSetting("group.lua", ["group", "groupbar"], "font_family", luaValue(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandGroupbarFontSize(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword group:groupbar:font_size " + value
            groupbarFontSizeProcess.command = ["sh", "-c", cmd]
            groupbarFontSizeProcess.startDetached()
            updateLuaSetting("group.lua", ["group", "groupbar"], "font_size", String(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandGroupbarGradients(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword group:groupbar:gradients " + (enabled ? "true" : "false")
            groupbarGradientsProcess.command = ["sh", "-c", cmd]
            groupbarGradientsProcess.startDetached()
            updateLuaSetting("group.lua", ["group", "groupbar"], "gradients", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandGroupbarTextColor(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword group:groupbar:text_color " + value
            groupbarTextColorProcess.command = ["sh", "-c", cmd]
            groupbarTextColorProcess.startDetached()
            updateLuaSetting("group.lua", ["group", "groupbar"], "text_color", luaValue(value))
            return true
        } catch (error) { return false }
    }

    function applyHyprlandGroupbarRounding(value) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword group:groupbar:rounding " + value
            groupbarRoundingProcess.command = ["sh", "-c", cmd]
            groupbarRoundingProcess.startDetached()
            updateLuaSetting("group.lua", ["group", "groupbar"], "rounding", String(value))
            return true
        } catch (error) { return false }
    }

    // Dwindle functions
    function applyHyprlandDwindlePreserveSplit(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword dwindle:preserve_split " + (enabled ? "true" : "false")
            dwindlePreserveSplitProcess.command = ["sh", "-c", cmd]
            dwindlePreserveSplitProcess.startDetached()
            updateLuaSetting("layout.lua", ["dwindle"], "preserve_split", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandDwindleSmartSplit(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword dwindle:smart_split " + (enabled ? "true" : "false")
            dwindleSmartSplitProcess.command = ["sh", "-c", cmd]
            dwindleSmartSplitProcess.startDetached()
            updateLuaSetting("layout.lua", ["dwindle"], "smart_split", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandDwindleSmartResizing(enabled) {
        if (!isHyprland) { return false }
        try {
            var cmd = "hyprctl keyword dwindle:smart_resizing " + (enabled ? "true" : "false")
            dwindleSmartResizingProcess.command = ["sh", "-c", cmd]
            dwindleSmartResizingProcess.startDetached()
            updateLuaSetting("layout.lua", ["dwindle"], "smart_resizing", enabled ? "true" : "false")
            return true
        } catch (error) { return false }
    }

    function applyHyprlandAnimationWindowsEnabled(enabled) {
        if (!isHyprland) { return false }
        try {
            var speed = SettingsData.hyprlandAnimationsSpeed || 10
            var curve = SettingsData.hyprlandAnimationsCurrentCurve || "default"
            hyprKeyword1.command = ["sh", "-c", "hyprctl keyword animation windows," + (enabled ? "1" : "0") + "," + speed + "," + curve]
            hyprKeyword1.startDetached()
            return true
        } catch (error) { return false }
    }

    function applyHyprlandAnimationWorkspacesEnabled(enabled) {
        if (!isHyprland) { return false }
        try {
            var speed = SettingsData.hyprlandAnimationsSpeed || 10
            var curve = SettingsData.hyprlandAnimationsCurrentCurve || "default"
            hyprKeyword1.command = ["sh", "-c", "hyprctl keyword animation workspaces," + (enabled ? "1" : "0") + "," + speed + "," + curve]
            hyprKeyword1.startDetached()
            return true
        } catch (error) { return false }
    }

    function applyHyprlandAnimationFadeEnabled(enabled) {
        if (!isHyprland) { return false }
        try {
            var speed = SettingsData.hyprlandAnimationsSpeed || 10
            var curve = SettingsData.hyprlandAnimationsCurrentCurve || "default"
            hyprKeyword1.command = ["sh", "-c", "hyprctl keyword animation fade," + (enabled ? "1" : "0") + "," + speed + "," + curve]
            hyprKeyword1.startDetached()
            return true
        } catch (error) { return false }
    }

    function applyHyprlandAnimationSpeed(speed) {
        if (!isHyprland) { return false }
        try {
            var curve = SettingsData.hyprlandAnimationsCurrentCurve || "default"
            var winEnabled = SettingsData.hyprlandAnimationsWindowsEnabled !== false ? "1" : "0"
            var wsEnabled = SettingsData.hyprlandAnimationsWorkspacesEnabled !== false ? "1" : "0"
            var fadeEnabled = SettingsData.hyprlandAnimationsFadeEnabled !== false ? "1" : "0"
            hyprKeyword1.command = ["sh", "-c",
                "hyprctl keyword animation windows," + winEnabled + "," + speed + "," + curve + " && " +
                "hyprctl keyword animation workspaces," + wsEnabled + "," + speed + "," + curve + " && " +
                "hyprctl keyword animation fade," + fadeEnabled + "," + speed + "," + curve]
            hyprKeyword1.startDetached()
            return true
        } catch (error) { return false }
    }

    Process { id: hyprKeyword1; command: ["true"] }
    Process { id: hyprKeyword2; command: ["true"] }
    Process { id: hyprKeyword3; command: ["true"] }
    Process { id: hyprKeyword4; command: ["true"] }
    Process { id: hyprKeyword5; command: ["true"] }
    Process { id: hyprKeyword6; command: ["true"] }
    Process { id: hyprKeyword7; command: ["true"] }
    Process { id: borderUpdateProcess; command: ["true"] }
    Process { id: borderColorUpdateProcess; command: ["true"] }
    Process { id: blurConfigUpdateProcess1; command: ["true"] }
    Process { id: blurConfigUpdateProcess2; command: ["true"] }
    Process { id: inputUpdateProcess; command: ["true"] }
    Process { id: cursorUpdateProcess; command: ["true"] }
    Process { 
        id: decorationUpdateProcess; 
        command: ["true"]
        onExited: (code, status) => {
            console.log("[Render] Process exited with code:", code, "status:", status)
        }
    }
    Process { id: masterOrientationProcess; command: ["true"] }
    Process { id: masterAllowSmallSplitProcess; command: ["true"] }
    Process { id: masterSpecialScaleFactorProcess; command: ["true"] }
    Process { id: masterMfactProcess; command: ["true"] }
    Process { id: masterNewStatusProcess; command: ["true"] }
    Process { id: masterNewOnTopProcess; command: ["true"] }
    Process { id: masterNewOnActiveProcess; command: ["true"] }
    Process { id: masterSlaveCountProcess; command: ["true"] }
    Process { id: masterCenterMasterFallbackProcess; command: ["true"] }
    Process { id: masterSmartResizingProcess; command: ["true"] }
    Process { id: masterDropAtCursorProcess; command: ["true"] }
    Process { id: masterAlwaysKeepPositionProcess; command: ["true"] }
    Process { id: scrollingFullscreenProcess; command: ["true"] }
    Process { id: scrollingColumnWidthProcess; command: ["true"] }
    Process { id: scrollingFocusFitMethodProcess; command: ["true"] }
    Process { id: scrollingFollowFocusProcess; command: ["true"] }
    Process { id: scrollingFollowMinVisibleProcess; command: ["true"] }
    Process { id: scrollingExplicitColumnWidthsProcess; command: ["true"] }
    Process { id: scrollingWrapFocusProcess; command: ["true"] }
    Process { id: scrollingWrapSwapcolProcess; command: ["true"] }
    Process { id: scrollingDirectionProcess; command: ["true"] }
    Process { id: groupbarEnabledProcess; command: ["true"] }
    Process { id: groupbarColActiveProcess; command: ["true"] }
    Process { id: groupbarColInactiveProcess; command: ["true"] }
    Process { id: groupbarHeightProcess; command: ["true"] }
    Process { id: groupbarPriorityProcess; command: ["true"] }
    Process { id: groupbarRenderTitlesProcess; command: ["true"] }
    Process { id: groupbarFontFamilyProcess; command: ["true"] }
    Process { id: groupbarFontSizeProcess; command: ["true"] }
    Process { id: groupbarGradientsProcess; command: ["true"] }
    Process { id: groupbarTextColorProcess; command: ["true"] }
    Process { id: groupbarRoundingProcess; command: ["true"] }
    Process { id: dwindlePreserveSplitProcess; command: ["true"] }
    Process { id: dwindleSmartSplitProcess; command: ["true"] }
    Process { id: dwindleSmartResizingProcess; command: ["true"] }
    Process { id: luaWriteProcess; command: ["true"] }
    Process { id: luaColorsProcess; command: ["true"] }
    Process { id: luaAnimationWriteProcess; command: ["true"] }
}