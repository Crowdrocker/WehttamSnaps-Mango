import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Settings
import qs.Services
import qs.Widgets

Item {


    id: displayConfigTab

    property var monitors: []
    property var monitorCapabilities: ({
    })
    property var rawMonitorData: []
    property bool loading: true
    property bool hasUnsavedChanges: false
    property string originalContent: ""
    property string selectedMonitor: ""
    readonly property string monitorsConfPath: {
        if (CompositorService.isNiri)
            return (Quickshell.env("HOME") || Paths.stringify(StandardPaths.writableLocation(StandardPaths.HomeLocation))) + "/.config/niri/eh/outputs.kdl";

        if (CompositorService.isMango)
            return (Quickshell.env("HOME") || Paths.stringify(StandardPaths.writableLocation(StandardPaths.HomeLocation))) + "/.config/mango/monitors.conf";

        return (Quickshell.env("HOME") || Paths.stringify(StandardPaths.writableLocation(StandardPaths.HomeLocation))) + "/.config/hypr/monitors.lua";
    }
    readonly property string capabilitiesCachePath: Paths.stringify(`${StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)}/EventHorizon/monitor-capabilities.json`)
    readonly property string niriMonitorsCachePath: Paths.stringify(`${StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)}/EventHorizon/niri-monitors.json`)
    readonly property string mangoMonitorsCachePath: Paths.stringify(`${StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)}/EventHorizon/mango-monitors.json`)
    property var previousMonitorSetup: null
    property string pendingSaveContent: ""
    property string pendingCapabilitiesContent: ""
    property string pendingNiriMonitorsContent: ""
    property string pendingMangoMonitorsContent: ""
    readonly property string hyprMonitorsCachePath: Paths.stringify(`${StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)}/EventHorizon/hypr-monitors.json`)
    property string pendingHyprMonitorsContent: ""
    property int mangoHdrDepth: 2

    readonly property string mangoMiscConfPath: (Quickshell.env("HOME") || Paths.stringify(StandardPaths.writableLocation(StandardPaths.HomeLocation))) + "/.config/mango/hyprmango/misc.conf"

    signal tabActivated()

    function loadPreviousMonitorSetup() {
        capabilitiesCacheFile.path = "";
        capabilitiesCacheFile.path = capabilitiesCachePath;
    }

    function getFilteredMonitors() {
        if (selectedMonitor === "")
            return monitors;

        return monitors.filter(function(m) {
            return m.name === selectedMonitor;
        });
    }

    function parseHdrDepthFromMisc(content) {
        if (!content) return;
        var lines = String(content).split("\n");
        for (var i = 0; i < lines.length; i++) {
            var t = lines[i].trim();
            if (t.startsWith("#") || !t) continue;
            var m = t.match(/^\s*hdr_depth\s*=\s*(\d+)/);
            if (m) {
                var v = parseInt(m[1], 10);
                if (!isNaN(v) && v >= 0 && v <= 2)
                    displayConfigTab.mangoHdrDepth = v;
                return;
            }
        }
    }

    function writeHdrDepthToMisc(value) {
        var v = parseInt(value, 10);
        if (isNaN(v) || v < 0 || v > 2) v = 2;
        updateHdrDepthProcess.command = ["bash", "-c",
            "f='" + mangoMiscConfPath + "'; " +
            "if grep -q '^\\s*hdr_depth\\s*=' \"$f\" 2>/dev/null; then " +
            "sed -i 's/^\\s*hdr_depth\\s*=.*/hdr_depth = " + v + "/' \"$f\"; " +
            "else mkdir -p \"$(dirname \"$f\")\" && echo 'hdr_depth = " + v + "' >> \"$f\"; fi"
        ];
        updateHdrDepthProcess.running = true;
    }

    function parseMonitorsConf(content) {
        if (CompositorService.isMango)
            return parseMangoMonitorsConf(content);

        if (!CompositorService.isNiri && content.trim().startsWith('hl.monitor('))
            return parseLuaMonitorsConf(content);

        var monitors = [];
        var lines = content.split('\n');
        var currentMonitor = null;
        var inMonitorV2Block = false;
        var inNiriOutputBlock = false;
        
        // Check if this is Niri format (starts with output) or Hyprland format
        var isNiriFormat = content.trim().startsWith('output "') || content.trim().startsWith('output\"');
        
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line === '' || line.startsWith('#'))
                continue;

            // Handle Niri output {} block format
            if (line.startsWith('output ') && line.includes('{')) {
                inNiriOutputBlock = true;
                inMonitorV2Block = false;
                if (currentMonitor)
                    monitors.push(currentMonitor);

                // Extract output name from "output "NAME" {" or "output NAME {"
                var nameMatch = line.match(/output\s+["']?([^"'{]+)["']?\s*\{/);
                currentMonitor = {
                    "name": nameMatch ? nameMatch[1].trim() : "",
                    "resolution": "",
                    "position": "",
                    "scale": "1",
                    "refreshRate": "",
                    "transform": "",
                    "disabled": false,
                    "bitdepth": "",
                    "cm": "",
                    "sdrbrightness": 1,
                    "sdrsaturation": 1,
                    "sdr_eotf": 0,
                    "vrr": "",
                    "custom": "",
                    "mirror": "",
                    "supports_wide_color": 0,
                    "supports_hdr": 0,
                    "hdr_depth": 2,
                    "sdr_min_luminance": 0,
                    "sdr_max_luminance": 200,
                    "min_luminance": 0,
                    "max_luminance": 0,
                    "max_avg_luminance": 0,
                    "isV2": true
                };
                continue;
            }
            
            // Handle end of Niri output block
            if (inNiriOutputBlock && line === '}') {
                inNiriOutputBlock = false;
                if (currentMonitor) {
                    monitors.push(currentMonitor);
                    currentMonitor = null;
                }
                continue;
            }
            
            // Parse Niri format properties inside output block
            if (inNiriOutputBlock && currentMonitor) {
                // Handle mode "1920x1080@120"
                if (line.startsWith('mode ')) {
                    var modeValue = line.substring(5).trim().replace(/^"|"$/g, '');
                    if (modeValue.includes('@')) {
                        var parts = modeValue.split('@');
                        currentMonitor.resolution = parts[0].trim();
                        currentMonitor.refreshRate = parts[1].trim();
                    } else {
                        currentMonitor.resolution = modeValue;
                    }
                }
                // Handle position x=1280 y=0
                else if (line.startsWith('position ')) {
                    var posValue = line.substring(9).trim();
                    var xMatch = posValue.match(/x\s*=\s*(\d+)/);
                    var yMatch = posValue.match(/y\s*=\s*(\d+)/);
                    if (xMatch && yMatch) {
                        currentMonitor.position = xMatch[1] + "x" + yMatch[1];
                    }
                }
                // Handle scale 2.0
                else if (line.startsWith('scale ')) {
                    currentMonitor.scale = line.substring(6).trim();
                }
                // Handle transform "90"
                else if (line.startsWith('transform ')) {
                    currentMonitor.transform = line.substring(10).trim().replace(/^"|"$/g, '');
                }
                // Handle off (disabled)
                else if (line === 'off') {
                    currentMonitor.disabled = true;
                }
                // Handle variable-refresh-rate
                else if (line.includes('variable-refresh-rate')) {
                    if (line.includes('on-demand=true')) {
                        currentMonitor.vrr = "2";
                    } else {
                        currentMonitor.vrr = "1";
                    }
                }
                continue;
            }

            // Handle Hyprland monitorv2 block
            if (line.startsWith('monitorv2') && line.includes('{')) {
                inMonitorV2Block = true;
                inNiriOutputBlock = false;
                if (currentMonitor)
                    monitors.push(currentMonitor);

                currentMonitor = {
                    "name": "",
                    "resolution": "",
                    "position": "",
                    "scale": "1",
                    "refreshRate": "",
                    "transform": "",
                    "disabled": false,
                    "bitdepth": "",
                    "cm": "",
                    "sdrbrightness": 1,
                    "sdrsaturation": 1,
                    "sdr_eotf": 0,
                    "vrr": "",
                    "custom": "",
                    "mirror": "",
                    "supports_wide_color": 0,
                    "supports_hdr": 0,
                    "hdr_depth": 2,
                    "sdr_min_luminance": 0,
                    "sdr_max_luminance": 200,
                    "min_luminance": 0,
                    "max_luminance": 0,
                    "max_avg_luminance": 0,
                    "isV2": true
                };
                continue;
            }
            if (inMonitorV2Block) {
                if (line === '}') {
                    inMonitorV2Block = false;
                    if (currentMonitor) {
                        monitors.push(currentMonitor);
                        currentMonitor = null;
                    }
                    continue;
                }
                var keyValue = line.split('=');
                if (keyValue.length === 2) {
                    var key = keyValue[0].trim();
                    var value = keyValue[1].trim().replace(/^["']|["']$/g, '');
                    if (key === 'output') {
                        currentMonitor.name = value;
                    } else if (key === 'mode') {
                        if (value.includes('@')) {
                            var parts = value.split('@');
                            currentMonitor.resolution = parts[0].trim();
                            currentMonitor.refreshRate = parts[1].trim();
                        } else {
                            currentMonitor.resolution = value;
                        }
                    } else if (key === 'position')
                        currentMonitor.position = value;
                    else if (key === 'scale')
                        currentMonitor.scale = value;
                    else if (key === 'transform')
                        currentMonitor.transform = value;
                    else if (key === 'disabled')
                        currentMonitor.disabled = value === 'true' || value === '1';
                    else if (key === 'bitdepth')
                        currentMonitor.bitdepth = value;
                    else if (key === 'cm')
                        currentMonitor.cm = value;
                    else if (key === 'sdrbrightness')
                        currentMonitor.sdrbrightness = parseFloat(value) || 1;
                    else if (key === 'sdrsaturation')
                        currentMonitor.sdrsaturation = parseFloat(value) || 1;
                    else if (key === 'sdr_eotf')
                        currentMonitor.sdr_eotf = parseInt(value) || 0;
                    else if (key === 'vrr')
                        currentMonitor.vrr = value;
                    else if (key === 'mirror')
                        currentMonitor.mirror = value;
                    else if (key === 'supports_wide_color')
                        currentMonitor.supports_wide_color = parseInt(value) || 0;
                    else if (key === 'supports_hdr')
                        currentMonitor.supports_hdr = parseInt(value) || 0;
                    else if (key === 'sdr_min_luminance')
                        currentMonitor.sdr_min_luminance = parseFloat(value) || 0;
                    else if (key === 'sdr_max_luminance')
                        currentMonitor.sdr_max_luminance = parseInt(value) || 200;
                    else if (key === 'min_luminance')
                        currentMonitor.min_luminance = parseFloat(value) || 0;
                    else if (key === 'max_luminance')
                        currentMonitor.max_luminance = parseInt(value) || 0;
                    else if (key === 'max_avg_luminance')
                        currentMonitor.max_avg_luminance = parseInt(value) || 0;
                }
                continue;
            }
            if (line.startsWith('monitor=')) {
                if (currentMonitor)
                    monitors.push(currentMonitor);

                currentMonitor = {
                    "name": "",
                    "resolution": "",
                    "position": "",
                    "scale": "1",
                    "refreshRate": "",
                    "transform": "",
                    "disabled": false,
                    "bitdepth": "",
                    "cm": "",
                    "sdrbrightness": 1,
                    "sdrsaturation": 1,
                    "sdr_eotf": 0,
                    "vrr": "",
                    "custom": "",
                    "mirror": "",
                    "supports_wide_color": 0,
                    "supports_hdr": 0,
                    "hdr_depth": 2,
                    "sdr_min_luminance": 0,
                    "sdr_max_luminance": 200,
                    "min_luminance": 0,
                    "max_luminance": 0,
                    "max_avg_luminance": 0,
                    "isV2": false
                };
                var monitorValue = line.substring(9).trim();
                if (monitorValue.startsWith('"') && monitorValue.endsWith('"'))
                    monitorValue = monitorValue.slice(1, -1);

                if (monitorValue === 'disable') {
                    currentMonitor.disabled = true;
                    continue;
                }
                var parts = monitorValue.split(',');
                if (parts.length > 0) {
                    var namePart = parts[0].trim();
                    if (namePart.startsWith('"') && namePart.endsWith('"'))
                        namePart = namePart.slice(1, -1);

                    currentMonitor.name = namePart;
                    if (parts.length > 1) {
                        var resolutionPart = parts[1].trim();
                        if (resolutionPart.includes('@')) {
                            var resParts = resolutionPart.split('@');
                            currentMonitor.resolution = resParts[0].trim();
                            if (resParts.length > 1)
                                currentMonitor.refreshRate = resParts[1].trim();

                        } else {
                            currentMonitor.resolution = resolutionPart;
                        }
                    }
                    if (parts.length > 2)
                        currentMonitor.position = parts[2].trim();

                    if (parts.length > 3)
                        currentMonitor.scale = parts[3].trim();

                    if (parts.length > 4 && !currentMonitor.refreshRate)
                        currentMonitor.refreshRate = parts[4].trim();

                    if (parts.length > 5)
                        currentMonitor.transform = parts[5].trim();

                    for (var j = 6; j < parts.length; j += 2) {
                        if (j + 1 < parts.length) {
                            var argName = parts[j].trim();
                            var argValue = parts[j + 1].trim();
                            if (argName === 'bitdepth')
                                currentMonitor.bitdepth = argValue;
                            else if (argName === 'cm')
                                currentMonitor.cm = argValue;
                            else if (argName === 'sdrbrightness')
                                currentMonitor.sdrbrightness = parseFloat(argValue) || 1;
                            else if (argName === 'sdrsaturation')
                                currentMonitor.sdrsaturation = parseFloat(argValue) || 1;
                            else if (argName === 'sdr_eotf')
                                currentMonitor.sdr_eotf = parseInt(argValue) || 0;
                            else if (argName === 'vrr')
                                currentMonitor.vrr = argValue;
                            else if (argName === 'mirror')
                                currentMonitor.mirror = argValue;
                            else if (argName === 'transform')
                                currentMonitor.transform = argValue;
                        }
                    }
                }
            } else if (currentMonitor && line.startsWith('monitor:')) {
                var keyValue = line.substring(8).trim().split('=');
                if (keyValue.length === 2) {
                    var key = keyValue[0].trim();
                    var value = keyValue[1].trim();
                    if (key === 'hdr')
                        currentMonitor.supports_hdr = parseInt(value) || 0;
                    else if (key === 'sdrBrightness')
                        currentMonitor.sdrbrightness = parseFloat(value) || 1;
                    else if (key === 'colorManagement')
                        currentMonitor.cm = value;
                }
            }
        }
        if (currentMonitor)
            monitors.push(currentMonitor);

        return monitors;
    }

    function parseMangoMonitorsConf(content) {
        var out = [];
        var lines = (content || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var trimmed = lines[i].trim();
            if (trimmed === "")
                continue;

            var disabled = false;
            var ruleLine = trimmed;
            if (trimmed.charAt(0) === "#") {
                var afterHash = trimmed.replace(/^#\s*/, "");
                if (!afterHash.startsWith("monitorrule="))
                    continue;
                disabled = true;
                ruleLine = afterHash;
            } else if (!trimmed.startsWith("monitorrule=")) {
                continue;
            }

            var payload = ruleLine.substring("monitorrule=".length).trim();
            var m = mangoPayloadToMonitor(payload, disabled);
            if (m && m.name)
                out.push(m);
        }
        return out;
    }

    function mangoPayloadToMonitor(payload, disabled) {
        var params = {};
        var segments = payload.split(",");
        for (var s = 0; s < segments.length; s++) {
            var seg = segments[s].trim();
            var ci = seg.indexOf(":");
            if (ci <= 0)
                continue;
            params[seg.substring(0, ci).trim()] = seg.substring(ci + 1).trim();
        }
        var namePattern = params.name || "";
        var displayName = namePattern;
        if (displayName.length >= 2 && displayName.charAt(0) === "^" && displayName.charAt(displayName.length - 1) === "$")
            displayName = displayName.substring(1, displayName.length - 1);

        if (!displayName && !namePattern && !params.make && !params.model)
            return null;

        var w = parseInt(params.width, 10) || 0;
        var h = parseInt(params.height, 10) || 0;
        var x = parseInt(params.x, 10) || 0;
        var y = parseInt(params.y, 10) || 0;
        return {
            "name": displayName || namePattern,
            "mangoNamePattern": namePattern,
            "mangoMake": params.make || "",
            "mangoModel": params.model || "",
            "mangoSerial": params.serial || "",
            "resolution": (w && h) ? w + "x" + h : "",
            "position": x + "x" + y,
            "scale": params.scale !== undefined ? String(params.scale) : "1",
            "refreshRate": params.refresh !== undefined ? String(params.refresh) : "",
            "transform": params.rr !== undefined ? String(params.rr) : "0",
            "disabled": disabled,
            "bitdepth": "",
            "cm": "",
            "sdrbrightness": 1,
            "sdrsaturation": 1,
            "sdr_eotf": 0,
            "vrr": params.vrr !== undefined ? String(params.vrr) : "",
            "custom": params.custom !== undefined ? String(params.custom) : "",
            "mirror": "",
            "supports_wide_color": 0,
            "supports_hdr": params.hdr !== undefined ? parseInt(params.hdr, 10) || 0 : 0,
            "sdr_min_luminance": 0,
            "sdr_max_luminance": 200,
            "min_luminance": 0,
            "max_luminance": 0,
            "max_avg_luminance": 0,
            "icc": "",
            "isV2": true
        };
    }

    function mangoMungeNamePattern(plainName) {
        if (!plainName)
            return "^$";
        var esc = String(plainName).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        return "^" + esc + "$";
    }

    function luaValue(v) {
        var s = String(v);
        if (s === "true" || s === "false") return s;
        if (!isNaN(parseFloat(s)) && isFinite(s) && s.indexOf("0x") !== 0) return s;
        return '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }

    function parseLuaMonitorsConf(content) {
        var monitors = [];
        var lines = content.split('\n');
        var i = 0;

        while (i < lines.length) {
            var line = lines[i].trim();
            i++;

            if (line.startsWith('hl.monitor(') && line.indexOf('{') >= 0) {
                var braceCount = (line.match(/{/g) || []).length - (line.match(/}/g) || []).length;
                var blockLines = [];

                while (i < lines.length && braceCount > 0) {
                    var bline = lines[i];
                    braceCount += (bline.match(/{/g) || []).length;
                    braceCount -= (bline.match(/}/g) || []).length;
                    if (braceCount > 0 || (bline.trim() !== '' && bline.trim() !== '})'))
                        blockLines.push(bline);
                    i++;
                }

                var mon = {
                    "name": "",
                    "resolution": "",
                    "position": "",
                    "scale": "1",
                    "refreshRate": "",
                    "transform": "",
                    "disabled": false,
                    "bitdepth": "",
                    "cm": "",
                    "sdrbrightness": 1,
                    "sdrsaturation": 1,
                    "sdr_eotf": 0,
                    "vrr": "",
                    "custom": "",
                    "mirror": "",
                    "supports_wide_color": 0,
                    "supports_hdr": 0,
                    "hdr_depth": 2,
                    "sdr_min_luminance": 0,
                    "sdr_max_luminance": 200,
                    "min_luminance": 0,
                    "max_luminance": 0,
                    "max_avg_luminance": 0,
                    "icc": "",
                    "isV2": true
                };

                for (var j = 0; j < blockLines.length; j++) {
                    var bl = blockLines[j].trim();
                    if (bl === '' || bl.startsWith('--'))
                        continue;
                    var eqIdx = bl.indexOf('=');
                    if (eqIdx < 0) continue;
                    var key = bl.substring(0, eqIdx).trim();
                    var val = bl.substring(eqIdx + 1).trim().replace(/,$/, '').trim();

                    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'")))
                        val = val.slice(1, -1);

                    if (key === 'output')
                        mon.name = val;
                    else if (key === 'mode') {
                        if (val.includes('@')) {
                            var parts = val.split('@');
                            mon.resolution = parts[0].trim();
                            mon.refreshRate = parts[1].trim();
                        } else {
                            mon.resolution = val;
                        }
                    } else if (key === 'position')
                        mon.position = val;
                    else if (key === 'scale')
                        mon.scale = val;
                    else if (key === 'transform')
                        mon.transform = val;
                    else if (key === 'disabled')
                        mon.disabled = val === 'true' || val === '1';
                    else if (key === 'bitdepth')
                        mon.bitdepth = val;
                    else if (key === 'cm')
                        mon.cm = val;
                    else if (key === 'sdrbrightness')
                        mon.sdrbrightness = parseFloat(val) || 1;
                    else if (key === 'sdrsaturation')
                        mon.sdrsaturation = parseFloat(val) || 1;
                    else if (key === 'sdr_eotf')
                        mon.sdr_eotf = parseInt(val) || 0;
                    else if (key === 'vrr')
                        mon.vrr = val;
                    else if (key === 'mirror')
                        mon.mirror = val;
                    else if (key === 'supports_wide_color')
                        mon.supports_wide_color = parseInt(val) || 0;
                    else if (key === 'supports_hdr')
                        mon.supports_hdr = parseInt(val) || 0;
                    else if (key === 'sdr_min_luminance')
                        mon.sdr_min_luminance = parseFloat(val) || 0;
                    else if (key === 'sdr_max_luminance')
                        mon.sdr_max_luminance = parseInt(val) || 200;
                    else if (key === 'min_luminance')
                        mon.min_luminance = parseFloat(val) || 0;
                    else if (key === 'max_luminance')
                        mon.max_luminance = parseInt(val) || 0;
                    else if (key === 'max_avg_luminance')
                        mon.max_avg_luminance = parseInt(val) || 0;
                    else if (key === 'icc')
                        mon.icc = val;
                }

                if (mon.name)
                    monitors.push(mon);
            }
        }
        return monitors;
    }

    function buildMangoMonitorruleLine(monitor) {
        var pattern = monitor.mangoNamePattern;
        if (!pattern || pattern === "")
            pattern = mangoMungeNamePattern(monitor.name);

        var parts = ["monitorrule=name:" + pattern];
        if (monitor.mangoMake)
            parts.push("make:" + monitor.mangoMake);
        if (monitor.mangoModel)
            parts.push("model:" + monitor.mangoModel);
        if (monitor.mangoSerial)
            parts.push("serial:" + monitor.mangoSerial);
        if (monitor.resolution && monitor.resolution.indexOf("x") >= 0) {
            var wh = monitor.resolution.split("x");
            parts.push("width:" + (parseInt(wh[0], 10) || 0));
            parts.push("height:" + (parseInt(wh[1], 10) || 0));
        }
        if (monitor.refreshRate !== undefined && monitor.refreshRate !== null && String(monitor.refreshRate).trim() !== "")
            parts.push("refresh:" + String(monitor.refreshRate).trim());

        var pos = monitor.position || "0x0";
        var px = pos.split("x");
        parts.push("x:" + (parseInt(px[0], 10) || 0));
        parts.push("y:" + (parseInt(px.length > 1 ? px[1] : "0", 10) || 0));

        var sc = parseFloat(monitor.scale);
        if (isNaN(sc) || sc <= 0)
            sc = 1;
        parts.push("scale:" + sc);

        var vi = parseInt(monitor.vrr, 10);
        if (isNaN(vi) || vi < 0)
            vi = 0;
        if (vi > 1)
            vi = 1;
        parts.push("vrr:" + vi);

        var ci2 = parseInt(monitor.custom, 10);
        if (!isNaN(ci2) && ci2 > 0) {
            if (ci2 > 1)
                ci2 = 1;
            parts.push("custom:" + ci2);
        }

        var ti = parseInt(monitor.transform, 10) || 0;
        if (ti < 0)
            ti = 0;
        if (ti > 7)
            ti = 7;
        parts.push("rr:" + ti);

        var hi = parseInt(monitor.supports_hdr, 10) || 0;
        if (hi < 0)
            hi = 0;
        if (hi > 1)
            hi = 1;
        parts.push("hdr:" + hi);

        return parts.join(",");
    }

    function saveMangoMonitorsConf() {
        var content = originalContent || "";
        var linesIn = content ? content.split("\n") : [];
        var kept = [];
        for (var li = 0; li < linesIn.length; li++) {
            var L = linesIn[li];
            var t = L.trim();
            var uncom = t.startsWith("#") ? t.replace(/^#\s*/, "") : t;
            if (uncom.startsWith("monitorrule="))
                continue;
            kept.push(L);
        }
        while (kept.length > 0 && kept[kept.length - 1].trim() === "")
            kept.pop();

        var lines = kept;
        if (lines.length > 0)
            lines.push("");

        for (var j = 0; j < monitors.length; j++) {
            var mon = monitors[j];
            var ml = buildMangoMonitorruleLine(mon);
            if (mon.disabled)
                lines.push("# " + ml);
            else
                lines.push(ml);
        }
        if (lines.length > 0 && lines[lines.length - 1] !== "")
            lines.push("");

        var newContent = lines.join("\n");
        var dirPath = monitorsConfPath.substring(0, monitorsConfPath.lastIndexOf("/"));
        ensureDirProcess.command = ["mkdir", "-p", dirPath];
        ensureDirProcess.running = true;
        pendingSaveContent = newContent;
    }

    function loadMonitorsFromQuickshellScreens() {
        var list = [];
        var screens = Quickshell.screens || [];
        for (var si = 0; si < screens.length; si++) {
            var scr = screens[si];
            if (!scr)
                continue;
            var w = scr.width || 1920;
            var h = scr.height || 1080;
            var sx = scr.x !== undefined ? scr.x : 0;
            var sy = scr.y !== undefined ? scr.y : 0;
            var nm = scr.name || ("OUTPUT" + si);
            list.push({
                "name": nm,
                "mangoNamePattern": mangoMungeNamePattern(nm),
                "mangoMake": "",
                "mangoModel": "",
                "mangoSerial": "",
                "resolution": w + "x" + h,
                "position": sx + "x" + sy,
                "scale": (scr.devicePixelRatio || 1).toString(),
                "refreshRate": "",
                "transform": "0",
                "disabled": false,
                "bitdepth": "",
                "cm": "",
                "sdrbrightness": 1,
                "sdrsaturation": 1,
                "sdr_eotf": 0,
                "vrr": "0",
                "custom": "",
                "mirror": "",
                "supports_wide_color": 0,
                "supports_hdr": 0,
                "hdr_depth": 2,
                "sdr_min_luminance": 0,
                "sdr_max_luminance": 200,
                "min_luminance": 0,
                "max_luminance": 0,
                "max_avg_luminance": 0,
                "isV2": true
            });
        }
        // Normalize positions so the topmost/leftmost monitor starts at 0,0.
        // Quickshell.screens gives global compositor coordinates, but the
        // arrangement widget and config writer both expect a layout where the
        // bounding box origin is 0,0. Without this, a stacked layout where the
        // primary monitor is at y=1080 would write y:1080 to monitors.conf
        // instead of the correct relative offset, and the popup positioning
        // logic would be fed a non-zero base that it has already accounted for.
        if (list.length > 0) {
            var minX = Infinity, minY = Infinity;
            for (var ni = 0; ni < list.length; ni++) {
                var np = list[ni].position.split("x");
                var nx = parseInt(np[0], 10) || 0;
                var ny = parseInt(np[1], 10) || 0;
                if (nx < minX) minX = nx;
                if (ny < minY) minY = ny;
            }
            if (minX !== 0 || minY !== 0) {
                for (var ki = 0; ki < list.length; ki++) {
                    var kp = list[ki].position.split("x");
                    var kx = (parseInt(kp[0], 10) || 0) - minX;
                    var ky = (parseInt(kp[1], 10) || 0) - minY;
                    list[ki].position = kx + "x" + ky;
                }
            }
        }
        monitors = list;
        originalContent = "";
        loading = false;
        hasUnsavedChanges = false;
        // Fire dedicated detect process — independent of loadMangoWlrRandrProcess
        // so there is no race with Component.onCompleted startup sequence.
        if (CompositorService.isMango)
            mangoAutoCreateProcess.running = true;
    }

    function normalizeWlrRandrOutputs(rootJson) {
        if (!rootJson)
            return [];
        if (Array.isArray(rootJson))
            return rootJson;
        if (rootJson.outputs && Array.isArray(rootJson.outputs))
            return rootJson.outputs;
        var arr = [];
        for (var k in rootJson) {
            if (!rootJson.hasOwnProperty(k))
                continue;
            var v = rootJson[k];
            if (v && typeof v === "object" && (v.modes !== undefined || v.enabled !== undefined || v.rect !== undefined)) {
                var o = {};
                for (var kk in v) {
                    if (v.hasOwnProperty(kk))
                        o[kk] = v[kk];
                }
                if (!o.name)
                    o.name = k;
                arr.push(o);
            }
        }
        return arr;
    }

    function refreshMhzToHz(refresh) {
        var r = parseFloat(refresh);
        if (isNaN(r) || r <= 0)
            return 0;
        if (r > 500)
            return r / 1000;
        return r;
    }

    function wlrTransformToHyprIndex(t) {
        if (typeof t === "number")
            return Math.max(0, Math.min(7, t));
        var map = {
            "normal": 0,
            "90": 1,
            "180": 2,
            "270": 3,
            "flipped": 4,
            "flipped-90": 5,
            "flipped-180": 6,
            "flipped-270": 7
        };
        var s = String(t).toLowerCase();
        if (map[s] !== undefined)
            return map[s];
        return 0;
    }

    function loadMonitorsConf() {
        loading = true;
        monitorsFile.path = "";
        monitorsFile.path = monitorsConfPath;
    }

    function checkEdidHdrSupport() {
        for (var i = 0; i < monitors.length; i++) {
            var monitor = monitors[i];
            if (!monitor || monitor.disabled)
                continue;

            var caps = displayConfigTab.monitorCapabilities[monitor.name];
            if (caps && caps.hdr === true)
                continue;

            checkEdidForMonitor(monitor.name, i);
        }
    }

    function checkForMonitorChanges(currentMonitorData) {
        var currentSetup = {
            "count": currentMonitorData.length,
            "monitors": []
        };
        for (var i = 0; i < currentMonitorData.length; i++) {
            var monitor = currentMonitorData[i];
            currentSetup.monitors.push({
                "name": monitor.name,
                "description": monitor.description,
                "width": monitor.width,
                "height": monitor.height,
                "refresh": monitor.refreshRate
            });
        }
        currentSetup.monitors.sort(function(a, b) {
            return a.name.localeCompare(b.name);
        });
        if (!previousMonitorSetup) {
            console.log("No previous monitor setup found - this appears to be a fresh configuration");
            wipeMonitorsConf();
        }
        previousMonitorSetup = JSON.parse(JSON.stringify(currentSetup));
    }

    function wipeMonitorsConf() {
        var basicConfig = ["-- Monitor configuration reset due to monitor changes", "-- Please configure your monitors through the Monitors tab", ""].join('\n');
        wipeMonitorsConfFile.path = "";
        Qt.callLater(() => {
            wipeMonitorsConfFile.path = monitorsConfPath;
            Qt.callLater(() => {
                wipeMonitorsConfFile.setText(basicConfig);
            });
        });
    }

    function checkEdidForMonitor(monitorName, index) {
        edidCheckProcess.command = ["sh", "-c", "monitor=\"" + monitorName + "\"; " + "hyprctl monitors all 2>/dev/null | grep -A 50 \"$monitor\" | grep -q 'colorManagementPreset.*hdr' && echo 'HDR' && exit 0; " + "ddcutil detect --terse 2>/dev/null | grep -i \"$monitor\" >/dev/null && " + "ddcutil capabilities 2>/dev/null | grep -qiE '(hdr|bt\\.2020|rec\\.2020|wide.*color.*gamut|color.*space.*extended)' && echo 'HDR' && exit 0; " + "for card in /sys/class/drm/card*\"$monitor\"/edid; do " + "if [ -r \"$card\" ] 2>/dev/null; then " + "output=$(cat \"$card\" 2>/dev/null | edid-decode 2>&1); " + "echo \"$output\" | grep -qiE '(hdr.*static.*metadata|hdr.*metadata.*block|hdr.*static|hdr.*support|bt\\.2020|rec\\.2020|dci.*p3|wide.*color.*gamut|extended.*color.*space)' && echo 'HDR' && exit 0; " + "fi; done"];
        edidCheckProcess.monitorName = monitorName;
        edidCheckProcess.monitorIndex = index;
        edidCheckProcess.running = true;
    }

    function saveMonitorsConf() {
        // Use niri-specific save function if running on niri
        if (CompositorService.isNiri) {
            saveNiriOutputsConf();
            return ;
        }
        if (CompositorService.isMango) {
            saveMangoMonitorsConf();
            return ;
        }
        var lines = [];

        for (var j = 0; j < monitors.length; j++) {
            var monitor = monitors[j];
            var blockLines = [];

            blockLines.push("    output = " + luaValue(monitor.name));

            if (!monitor.disabled) {
                if (monitor.resolution) {
                    var mode = monitor.resolution;
                    if (monitor.refreshRate)
                        mode += "@" + monitor.refreshRate;
                    blockLines.push("    mode = " + luaValue(mode));
                }
                if (monitor.position)
                    blockLines.push("    position = " + luaValue(monitor.position));
                if (monitor.scale && monitor.scale !== "1")
                    blockLines.push("    scale = " + luaValue(monitor.scale));
                if (monitor.transform && monitor.transform !== "0")
                    blockLines.push("    transform = " + luaValue(monitor.transform));
                if (monitor.bitdepth)
                    blockLines.push("    bitdepth = " + (luaValue(monitor.bitdepth)));
                if (monitor.cm)
                    blockLines.push("    cm = " + luaValue(monitor.cm));
                if (monitor.sdrbrightness && monitor.sdrbrightness !== "1.0" && monitor.sdrbrightness !== 1)
                    blockLines.push("    sdrbrightness = " + monitor.sdrbrightness);
                if (monitor.sdrsaturation && monitor.sdrsaturation !== "1.0" && monitor.sdrsaturation !== 1)
                    blockLines.push("    sdrsaturation = " + monitor.sdrsaturation);
                if (monitor.sdr_eotf && monitor.sdr_eotf !== "0" && monitor.sdr_eotf !== 0)
                    blockLines.push("    sdr_eotf = " + monitor.sdr_eotf);
                if (monitor.vrr !== undefined && monitor.vrr !== null && monitor.vrr !== "")
                    blockLines.push("    vrr = " + luaValue(monitor.vrr));
                if (monitor.mirror)
                    blockLines.push("    mirror = " + luaValue(monitor.mirror));
                if (monitor.supports_wide_color !== undefined && monitor.supports_wide_color !== null && monitor.supports_wide_color !== 0)
                    blockLines.push("    supports_wide_color = " + monitor.supports_wide_color);
                if (monitor.supports_hdr !== undefined && monitor.supports_hdr !== null && monitor.supports_hdr !== 0)
                    blockLines.push("    supports_hdr = " + monitor.supports_hdr);
                if (monitor.sdr_min_luminance && monitor.sdr_min_luminance !== 0)
                    blockLines.push("    sdr_min_luminance = " + monitor.sdr_min_luminance);
                if (monitor.sdr_max_luminance && monitor.sdr_max_luminance !== 200)
                    blockLines.push("    sdr_max_luminance = " + monitor.sdr_max_luminance);
                if (monitor.min_luminance && monitor.min_luminance !== 0)
                    blockLines.push("    min_luminance = " + monitor.min_luminance);
                if (monitor.max_luminance && monitor.max_luminance !== 0)
                    blockLines.push("    max_luminance = " + monitor.max_luminance);
                if (monitor.max_avg_luminance && monitor.max_avg_luminance !== 0)
                    blockLines.push("    max_avg_luminance = " + monitor.max_avg_luminance);
                if (monitor.icc && monitor.icc !== "")
                    blockLines.push("    icc = " + luaValue(monitor.icc));
            }

            var block = "hl.monitor({\n" + blockLines.join(",\n") + ",\n})\n";
            if (monitor.disabled)
                block = "-- " + block.replace(/\n/g, "\n-- ").replace(/-- $/, "");

            lines.push(block);
        }

        var newContent = lines.join('\n');
        var dirPath = monitorsConfPath.substring(0, monitorsConfPath.lastIndexOf('/'));
        ensureDirProcess.command = ["mkdir", "-p", dirPath];
        ensureDirProcess.running = true;
        pendingSaveContent = newContent;
        if (!CompositorService.isMango && !CompositorService.isNiri)
            saveHyprMonitorsToCache();
    }

    function applyMonitorSetting(monitorName, setting, value) {
        var monitor = monitors.find(function(m) {
            return m.name === monitorName;
        });
        if (!monitor)
            return ;

        monitor[setting] = value;
        hasUnsavedChanges = true;
        saveMonitorsConf();
    }

    function applyMonitorPositionsBatch(batch) {
        if (!batch || batch.length === 0)
            return ;

        for (var i = 0; i < batch.length; i++) {
            var entry = batch[i];
            if (!entry || !entry.name)
                continue;

            var mon = monitors.find(function(m) {
                return m.name === entry.name;
            });
            if (mon && entry.position !== undefined)
                mon.position = entry.position;
        }
        hasUnsavedChanges = true;
        saveMonitorsConf();
    }

    function updateMonitorResolution(monitorName, resolution) {
        applyMonitorSetting(monitorName, "resolution", resolution);
    }

    function updateMonitorRefreshRate(monitorName, refreshRate) {
        applyMonitorSetting(monitorName, "refreshRate", refreshRate);
    }

    function saveNiriOutputsConf() {
        var lines = [];
        for (var j = 0; j < monitors.length; j++) {
            var monitor = monitors[j];
            lines.push('output "' + monitor.name + '" {');
            if (monitor.disabled) {
                lines.push("    off");
            } else {
                if (monitor.resolution) {
                    var mode = monitor.resolution;
                    if (monitor.refreshRate)
                        mode += "@" + monitor.refreshRate;

                    lines.push('    mode "' + mode + '"');
                }
                if (monitor.position) {
                    var posParts = monitor.position.split('x');
                    if (posParts.length === 2)
                        lines.push('    position x=' + posParts[0] + ' y=' + posParts[1]);

                }
                if (monitor.scale && monitor.scale !== "1")
                    lines.push('    scale ' + monitor.scale);

                if (monitor.transform && monitor.transform !== "0" && monitor.transform !== "")
                    lines.push('    transform "' + monitor.transform + '"');

                // Niri VRR support
                if (monitor.vrr && monitor.vrr !== "") {
                    if (monitor.vrr === "2") {
                        // on-demand mode
                        lines.push('    variable-refresh-rate on-demand=true');
                    } else if (monitor.vrr === "1" || monitor.vrr === true) {
                        // enabled
                        lines.push('    variable-refresh-rate');
                    }
                    // vrr === "0" or empty means disabled, don't add anything
                }
            }
            lines.push("}");
            lines.push("");
        }
        while (lines.length > 0 && lines[lines.length - 1].trim().length === 0)
            lines.pop();

        var newContent = lines.join('\n');
        var dirPath = monitorsConfPath.substring(0, monitorsConfPath.lastIndexOf('/'));
        ensureDirProcess.command = ["mkdir", "-p", dirPath];
        ensureDirProcess.running = true;
        pendingSaveContent = newContent;
    }

    function loadMonitorCapabilitiesFromCache() {
        capabilitiesCacheFile.path = "";
        capabilitiesCacheFile.path = capabilitiesCachePath;
    }

    function saveMonitorCapabilitiesToCache() {
        var cacheData = {
            "rawData": rawMonitorData,
            "processedData": monitorCapabilities,
            "timestamp": new Date().toISOString()
        };
        var capabilitiesJson = JSON.stringify(cacheData, null, 2);
        var dirPath = capabilitiesCachePath.substring(0, capabilitiesCachePath.lastIndexOf('/'));
        ensureCapabilitiesDirProcess.command = ["mkdir", "-p", dirPath];
        ensureCapabilitiesDirProcess.running = true;
        pendingCapabilitiesContent = capabilitiesJson;
    }

    function saveNiriMonitorsToCache(rawOutputsJson) {
        var cacheData = {
            "outputs": rawOutputsJson,
            "timestamp": new Date().toISOString()
        };
        var niriMonitorsJson = JSON.stringify(cacheData, null, 2);
        var dirPath = niriMonitorsCachePath.substring(0, niriMonitorsCachePath.lastIndexOf('/'));
        ensureNiriMonitorsDirProcess.command = ["mkdir", "-p", dirPath];
        ensureNiriMonitorsDirProcess.running = true;
        pendingNiriMonitorsContent = niriMonitorsJson;
    }

    function saveMangoMonitorsToCache(caps, rawArr) {
        var outputs = {};
        for (var oname in caps) {
            if (!caps.hasOwnProperty(oname)) continue;
            var c = caps[oname];
            // Current resolution string, e.g. "1920x1080"
            var curRes = (c.width > 0 && c.height > 0)
                ? (c.width + "x" + c.height)
                : "";
            // Current refresh as a clean string, e.g. "144" or "59.94"
            var curHz = c.refresh > 0
                ? (Number.isInteger(c.refresh) ? String(c.refresh) : c.refresh.toFixed(3).replace(/\.?0+$/, ""))
                : "";
            outputs[oname] = {
                "name":                oname,
                "description":         c.description || "",
                "make":                c.make || "",
                "model":               c.model || "",
                "vrr":                 c.vrr || false,
                "resolutions":         c.resolutions || [],
                "refreshRates":        c.refreshRates || [],
                "resolutionRefreshMap":c.resolutionRefreshMap || {},
                "availableModes":      c.availableModes || [],
                "scale":               c.scale || 1,
                "transform":           c.transform || 0,
                "disabled":            c.disabled || false,
                // current block — what the monitor is running right now
                "current": {
                    "resolution": curRes,
                    "refresh":    curHz,
                    "width":      c.width  || 0,
                    "height":     c.height || 0
                }
            };
        }
        var cacheData = {
            "outputs":   outputs,
            "rawData":   rawArr || [],
            "timestamp": new Date().toISOString()
        };
        var json = JSON.stringify(cacheData, null, 2);
        var dirPath = mangoMonitorsCachePath.substring(0, mangoMonitorsCachePath.lastIndexOf('/'));
        ensureMangoMonitorsDirProcess.command = ["mkdir", "-p", dirPath];
        ensureMangoMonitorsDirProcess.running = true;
        pendingMangoMonitorsContent = json;
    }

    function saveHyprMonitorsToCache() {
        var cacheData = {
            "monitors": monitors,
            "timestamp": new Date().toISOString()
        };
        var json = JSON.stringify(cacheData, null, 2);
        var dirPath = hyprMonitorsCachePath.substring(0, hyprMonitorsCachePath.lastIndexOf('/'));
        ensureHyprMonitorsDirProcess.command = ["mkdir", "-p", dirPath];
        ensureHyprMonitorsDirProcess.running = true;
        pendingHyprMonitorsContent = json;
    }

    function loadMonitorsFromHyprctl() {
        loadMonitorsFromHyprctlProcess.running = true;
    }

    function loadMonitorsFromNiri() {
        niriAutoCreateProcess.running = true;
    }

    function loadMonitorCapabilities() {
        if (CompositorService.isNiri)
            loadNiriCapabilitiesProcess.running = true;
        else if (CompositorService.isMango)
            loadMangoWlrRandrProcess.running = true;
        else
            loadCapabilitiesProcess.running = true;
        checkEdidHdrSupport();
    }

    Component.onCompleted: {
        loadMonitorsConf();
        loadMonitorCapabilitiesFromCache();
        Qt.callLater(() => {
            loadMonitorCapabilities();
        });
    }
    onTabActivated: {
        if (CompositorService.isNiri)
            loadNiriCapabilitiesProcess.running = true;
        else if (CompositorService.isMango) {
            loadMangoWlrRandrProcess.running = true;
            mangoMiscFile.reload();
        } else
            loadCapabilitiesProcess.running = true;
        checkEdidHdrSupport();
    }

    FileView {
        id: monitorsFile

        path: displayConfigTab.monitorsConfPath
        blockWrites: true
        blockLoading: false
        atomicWrites: true
        printErrors: true
        onLoaded: {
            var content = text();
            displayConfigTab.originalContent = content;
            var parsedMonitors = displayConfigTab.parseMonitorsConf(content);
            if (parsedMonitors.length === 0) {
                if (CompositorService.isNiri)
                    loadMonitorsFromNiri();
                else if (CompositorService.isMango)
                    loadMonitorsFromQuickshellScreens();
                else
                    loadMonitorsFromHyprctl();
            } else {
                // Detect hardcoded template monitors that don't match connected screens
                if (!CompositorService.isMango && !CompositorService.isNiri) {
                    var connectedNames = (Quickshell.screens || []).map(function(s) { return s.name; });
                    var anyMatch = parsedMonitors.some(function(m) {
                        return connectedNames.indexOf(m.name) !== -1;
                    });
                    if (connectedNames.length > 0 && !anyMatch) {
                        loadMonitorsFromHyprctl();
                        return;
                    }
                }
                displayConfigTab.monitors = parsedMonitors;
                displayConfigTab.loading = false;
                displayConfigTab.hasUnsavedChanges = false;
                if (Object.keys(displayConfigTab.monitorCapabilities).length === 0)
                    Qt.callLater(() => {
                        loadMonitorCapabilities();
                    });

            }
        }
        onLoadFailed: {
            if (CompositorService.isNiri)
                loadMonitorsFromNiri();
            else if (CompositorService.isMango)
                loadMonitorsFromQuickshellScreens();
            else
                loadMonitorsFromHyprctl();
        }
    }

    Process {
        id: loadMonitorsFromHyprctlProcess

        command: ["hyprctl", "-j", "monitors"]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    var json = JSON.parse(stdout.text);
                    var monitors = [];
                    for (var i = 0; i < json.length; i++) {
                        var monitor = json[i];
                        var monitorObj = {
                            "name": monitor.name || "Unknown",
                            "resolution": monitor.width + "x" + monitor.height,
                            "position": (monitor.x !== undefined && monitor.y !== undefined) ? (monitor.x + "x" + monitor.y) : "",
                            "scale": monitor.scale ? monitor.scale.toString() : "1",
                            "refreshRate": monitor.refresh ? monitor.refresh.toString() : "",
                            "transform": "",
                            "disabled": false,
                            "bitdepth": "",
                            "cm": "",
                            "sdrbrightness": 1,
                            "sdrsaturation": 1,
                            "sdr_eotf": 0,
                            "vrr": "",
                            "custom": "",
                            "mirror": "",
                            "supports_wide_color": 0,
                            "supports_hdr": monitor.hdr || false,
                            "hdr_depth": 2,
                            "sdr_min_luminance": 0,
                            "sdr_max_luminance": 200,
                            "min_luminance": 0,
                            "max_luminance": 0,
                            "max_avg_luminance": 0,
                            "icc": "",
                            "isV2": true
                        };
                        monitors.push(monitorObj);
                    }
                    displayConfigTab.monitors = monitors;
                    displayConfigTab.originalContent = "";
                    displayConfigTab.loading = false;
                    displayConfigTab.hasUnsavedChanges = false;
                    Qt.callLater(() => {
                        displayConfigTab.saveMonitorsConf();
                    });
                } catch (e) {
                    displayConfigTab.monitors = [];
                }
            } else {
                displayConfigTab.monitors = [];
            }
            displayConfigTab.loading = false;
        }

        stdout: StdioCollector {
        }

    }

    Process {
        id: loadMonitorsFromNiriProcess

        command: ["niri", "msg", "-j", "outputs"]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    var json = JSON.parse(stdout.text);
                    var monitors = [];
                    for (var outputName in json) {
                        var output = json[outputName];
                        if (!output)
                            continue;

                        // current_mode is an index into the modes array
                        var modeIndex = typeof output.current_mode === 'number' ? output.current_mode : -1;
                        var currentMode = (modeIndex >= 0 && output.modes && output.modes[modeIndex]) ? output.modes[modeIndex] : {};
                        var width = currentMode.width || 0;
                        var height = currentMode.height || 0;
                        var refresh = currentMode.refresh_rate || 0;

                        // position, scale, transform all live under logical
                        var logical = output.logical || {};
                        var position = (logical.x !== undefined && logical.y !== undefined) ? logical.x + "x" + logical.y : "";

                        // transform is a string like "Normal","90","180","270" etc
                        var transformMap = {"Normal":"0","90":"1","180":"2","270":"3","Flipped":"4","Flipped90":"5","Flipped180":"6","Flipped270":"7"};
                        var transformStr = transformMap[logical.transform] || "0";

                        var monitorObj = {
                            "name": outputName,
                            "resolution": (width && height) ? width + "x" + height : "",
                            "position": position,
                            "scale": logical.scale ? logical.scale.toString() : "1",
                            "refreshRate": refresh ? (refresh / 1000).toFixed(3) : "",
                            "transform": transformStr,
                            "disabled": !output.logical,
                            "bitdepth": "",
                            "cm": "",
                            "sdrbrightness": 1,
                            "sdrsaturation": 1,
                            "sdr_eotf": 0,
                            "vrr": output.vrr_enabled ? "1" : "0",
                            "custom": "",
                            "mirror": "",
                            "supports_wide_color": 0,
                            "supports_hdr": false,
                            "hdr_depth": 2,
                            "sdr_min_luminance": 0,
                            "sdr_max_luminance": 200,
                            "min_luminance": 0,
                            "max_luminance": 0,
                            "max_avg_luminance": 0,
                            "isV2": true
                        };
                        monitors.push(monitorObj);
                    }
                    displayConfigTab.monitors = monitors;
                    displayConfigTab.originalContent = "";
                    displayConfigTab.loading = false;
                    displayConfigTab.hasUnsavedChanges = false;
                } catch (e) {
                    console.warn("Failed to parse niri outputs:", e);
                    displayConfigTab.monitors = [];
                }
            } else {
                displayConfigTab.monitors = [];
            }
            displayConfigTab.loading = false;
        }

        stdout: StdioCollector {
        }

    }

    Process {
        id: loadCapabilitiesProcess

        command: ["hyprctl", "-j", "monitors"]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    var json = JSON.parse(stdout.text);
                    displayConfigTab.rawMonitorData = json;
                    var caps = {
                    };
                    for (var i = 0; i < json.length; i++) {
                        var monitor = json[i];
                        var refreshRates = [];
                        var resolutions = [];
                        var resolutionRefreshMap = {
                        };
                        if (monitor.availableModes && Array.isArray(monitor.availableModes)) {
                            for (var j = 0; j < monitor.availableModes.length; j++) {
                                var modeStr = monitor.availableModes[j];
                                var match = modeStr.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
                                if (match) {
                                    var width = parseInt(match[1]);
                                    var height = parseInt(match[2]);
                                    var refresh = parseFloat(match[3]);
                                    var res = width + "x" + height;
                                    if (!refreshRates.includes(refresh))
                                        refreshRates.push(refresh);

                                    if (!resolutions.includes(res))
                                        resolutions.push(res);

                                    if (!resolutionRefreshMap[res])
                                        resolutionRefreshMap[res] = [];

                                    if (!resolutionRefreshMap[res].includes(refresh))
                                        resolutionRefreshMap[res].push(refresh);

                                }
                            }
                        }
                        refreshRates = refreshRates.filter(function(value, index, self) {
                            return self.indexOf(value) === index;
                        }).sort(function(a, b) {
                            return b - a;
                        });
                        resolutions = resolutions.filter(function(value, index, self) {
                            return self.indexOf(value) === index;
                        }).sort(function(a, b) {
                            var aParts = a.split('x');
                            var bParts = b.split('x');
                            var aPixels = parseInt(aParts[0]) * parseInt(aParts[1]);
                            var bPixels = parseInt(bParts[0]) * parseInt(bParts[1]);
                            return bPixels - aPixels;
                        });
                        for (var res in resolutionRefreshMap) {
                            resolutionRefreshMap[res].sort(function(a, b) {
                                return b - a;
                            });
                        }
                        var hdrFromHyprctl = monitor.hdr === true || (monitor.colorManagementPreset && monitor.colorManagementPreset.toLowerCase().includes('hdr'));
                        var hdrFromConfig = false;
                        for (var k = 0; k < displayConfigTab.monitors.length; k++) {
                            var configMonitor = displayConfigTab.monitors[k];
                            if (configMonitor.name === monitor.name) {
                                var cm = (configMonitor.cm || "").toLowerCase();
                                hdrFromConfig = (cm === "hdr" || cm === "hdredid") || configMonitor.supports_hdr === true || configMonitor.supports_hdr === 1;
                                break;
                            }
                        }
                        caps[monitor.name] = {
                            "refreshRates": refreshRates,
                            "resolutions": resolutions,
                            "resolutionRefreshMap": resolutionRefreshMap,
                            "availableModes": monitor.availableModes || [],
                            "vrr": monitor.vrr !== undefined ? monitor.vrr : false,
                            "hdr": hdrFromHyprctl || hdrFromConfig,
                            "hdrFromEdid": false,
                            "currentMode": monitor.activeWorkspace ? monitor.activeWorkspace : null,
                            "width": monitor.width || 0,
                            "height": monitor.height || 0,
                            "refresh": monitor.refreshRate || monitor.refresh || 0,
                            "scale": monitor.scale || 1,
                            "description": monitor.description || "",
                            "make": monitor.make || "",
                            "model": monitor.model || "",
                            "transform": monitor.transform || 0,
                            "disabled": monitor.disabled || false,
                            "currentFormat": monitor.currentFormat || "",
                            "mirrorOf": monitor.mirrorOf || "none",
                            "colorManagementPreset": monitor.colorManagementPreset || "",
                            "sdrBrightness": monitor.sdrBrightness || 1,
                            "sdrSaturation": monitor.sdrSaturation || 1,
                            "sdrMinLuminance": monitor.sdrMinLuminance || 0,
                            "sdrMaxLuminance": monitor.sdrMaxLuminance || 0,
                            "dpmsStatus": monitor.dpmsStatus !== undefined ? monitor.dpmsStatus : true,
                            "focused": monitor.focused !== undefined ? monitor.focused : false
                        };
                    }
                    displayConfigTab.monitorCapabilities = caps;
                    checkForMonitorChanges(json);
                    saveMonitorCapabilitiesToCache();
                    Qt.callLater(() => {
                        checkEdidHdrSupport();
                    });
                } catch (e) {
                    displayConfigTab.monitorCapabilities = {
                    };
                    displayConfigTab.rawMonitorData = [];
                }
            } else {
                displayConfigTab.monitorCapabilities = {
                };
                displayConfigTab.rawMonitorData = [];
            }
        }

        stdout: StdioCollector {
        }

    }

    Process {
        id: loadNiriCapabilitiesProcess

        command: ["niri", "msg", "-j", "outputs"]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    var json = JSON.parse(stdout.text);
                    displayConfigTab.rawMonitorData = json;
                    var caps = {
                    };
                    for (var outputName in json) {
                        var output = json[outputName];
                        if (!output)
                            continue;

                        var refreshRates = [];
                        var resolutions = [];
                        var resolutionRefreshMap = {
                        };
                        if (output.modes && Array.isArray(output.modes)) {
                            for (var j = 0; j < output.modes.length; j++) {
                                var mode = output.modes[j];
                                var width = mode.width || 0;
                                var height = mode.height || 0;
                                var refresh = mode.refresh_rate || 0;
                                var res = width + "x" + height;
                                var refreshHz = refresh / 1000;
                                if (!refreshRates.includes(refreshHz))
                                    refreshRates.push(refreshHz);

                                if (!resolutions.includes(res))
                                    resolutions.push(res);

                                if (!resolutionRefreshMap[res])
                                    resolutionRefreshMap[res] = [];

                                if (!resolutionRefreshMap[res].includes(refreshHz))
                                    resolutionRefreshMap[res].push(refreshHz);

                            }
                        }
                        refreshRates = refreshRates.filter(function(value, index, self) {
                            return self.indexOf(value) === index;
                        }).sort(function(a, b) {
                            return b - a;
                        });
                        resolutions = resolutions.filter(function(value, index, self) {
                            return self.indexOf(value) === index;
                        }).sort(function(a, b) {
                            var aParts = a.split('x');
                            var bParts = b.split('x');
                            var aPixels = parseInt(aParts[0]) * parseInt(aParts[1]);
                            var bPixels = parseInt(bParts[0]) * parseInt(bParts[1]);
                            return bPixels - aPixels;
                        });
                        for (var res in resolutionRefreshMap) {
                            resolutionRefreshMap[res].sort(function(a, b) {
                                return b - a;
                            });
                        }
                        // current_mode is an index into the modes array
                        var modeIdx = typeof output.current_mode === 'number' ? output.current_mode : -1;
                        var currentMode = (modeIdx >= 0 && output.modes && output.modes[modeIdx]) ? output.modes[modeIdx] : {};
                        var logical = output.logical || {};
                        caps[outputName] = {
                            "refreshRates": refreshRates,
                            "resolutions": resolutions,
                            "resolutionRefreshMap": resolutionRefreshMap,
                            "availableModes": output.modes || [],
                            "vrr": output.vrr_supported ? output.vrr_enabled : null,
                            "hdr": false,
                            "hdrFromEdid": false,
                            "currentMode": currentMode,
                            "width": currentMode.width || 0,
                            "height": currentMode.height || 0,
                            "refresh": currentMode.refresh_rate ? (currentMode.refresh_rate / 1000) : 0,
                            "scale": logical.scale || 1,
                            "description": output.description || "",
                            "make": output.make || "",
                            "model": output.model || "",
                            "transform": logical.transform || "Normal",
                            "disabled": !output.logical,
                            "currentFormat": "",
                            "mirrorOf": "none",
                            "colorManagementPreset": "",
                            "sdrBrightness": 1,
                            "sdrSaturation": 1,
                            "sdrMinLuminance": 0,
                            "sdrMaxLuminance": 0,
                            "dpmsStatus": true,
                            "focused": output.current_workspace !== undefined
                        };
                    }
                    displayConfigTab.monitorCapabilities = caps;
                    checkForMonitorChanges(json);
                    saveMonitorCapabilitiesToCache();
                    // Save raw Niri outputs to niri-monitors.json
                    saveNiriMonitorsToCache(json);
                } catch (e) {
                    console.warn("Failed to parse niri capabilities:", e);
                    displayConfigTab.monitorCapabilities = {
                    };
                    displayConfigTab.rawMonitorData = [];
                }
            } else {
                displayConfigTab.monitorCapabilities = {
                };
                displayConfigTab.rawMonitorData = [];
            }
        }

        stdout: StdioCollector {
        }

    }

    Process {
        id: loadMangoWlrRandrProcess

        command: ["wlr-randr", "--json"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                displayConfigTab.monitorCapabilities = {
                };
                displayConfigTab.rawMonitorData = [];
                return ;
            }
            try {
                var rootJ = JSON.parse(stdout.text);
                var outs = displayConfigTab.normalizeWlrRandrOutputs(rootJ);
                var caps = {
                };
                var rawArr = [];
                for (var oi = 0; oi < outs.length; oi++) {
                    var wlrOut = outs[oi];
                    var oname = wlrOut.name || "OUT" + oi;
                    var modes = wlrOut.modes || [];
                    var refreshRates = [];
                    var resolutions = [];
                    var resolutionRefreshMap = {
                    };
                    for (var mj = 0; mj < modes.length; mj++) {
                        var md = modes[mj];
                        var mw = md.width || 0;
                        var mh = md.height || 0;
                        var mref = displayConfigTab.refreshMhzToHz(md.refresh || 0);
                        var res = mw + "x" + mh;
                        if (mref > 0 && !refreshRates.includes(mref))
                            refreshRates.push(mref);

                        if (mw && mh && !resolutions.includes(res))
                            resolutions.push(res);

                        if (!resolutionRefreshMap[res])
                            resolutionRefreshMap[res] = [];

                        if (mref > 0 && !resolutionRefreshMap[res].includes(mref))
                            resolutionRefreshMap[res].push(mref);

                    }
                    refreshRates.sort(function(a, b) {
                        return b - a;
                    });
                    resolutions.sort(function(a, b) {
                        var aParts = a.split('x');
                        var bParts = b.split('x');
                        var aPixels = parseInt(aParts[0]) * parseInt(aParts[1]);
                        var bPixels = parseInt(bParts[0]) * parseInt(bParts[1]);
                        return bPixels - aPixels;
                    });
                    for (var rk in resolutionRefreshMap) {
                        resolutionRefreshMap[rk].sort(function(a, b) {
                            return b - a;
                        });
                    }
                    var rect = wlrOut.rect || {
                    };
                    var cm = wlrOut.current_mode || wlrOut.mode || {
                    };
                    var cw = cm.width || rect.width || 0;
                    var ch = cm.height || rect.height || 0;
                    var curHz = displayConfigTab.refreshMhzToHz(cm.refresh || 0);
                    var vrrCap = wlrOut.adaptive_sync === true || wlrOut.adaptive_sync === 1;
                    caps[oname] = {
                        "refreshRates": refreshRates,
                        "resolutions": resolutions,
                        "resolutionRefreshMap": resolutionRefreshMap,
                        "availableModes": modes,
                        "vrr": vrrCap,
                        "hdr": false,
                        "hdrFromEdid": false,
                        "currentMode": cm,
                        "width": cw,
                        "height": ch,
                        "refresh": curHz,
                        "scale": wlrOut.scale !== undefined ? wlrOut.scale : 1,
                        "description": wlrOut.description || "",
                        "make": wlrOut.make || "",
                        "model": wlrOut.model || "",
                        "transform": displayConfigTab.wlrTransformToHyprIndex(wlrOut.transform),
                        "disabled": wlrOut.enabled === false,
                        "currentFormat": "",
                        "mirrorOf": "none",
                        "colorManagementPreset": "",
                        "sdrBrightness": 1,
                        "sdrSaturation": 1,
                        "dpmsStatus": wlrOut.enabled !== false,
                        "focused": false
                    };
                    rawArr.push({
                        "name": oname,
                        "description": wlrOut.description || "",
                        "width": cw,
                        "height": ch,
                        "refreshRate": curHz
                    });
                }
                displayConfigTab.rawMonitorData = rawArr;
                displayConfigTab.monitorCapabilities = caps;
                checkForMonitorChanges(rawArr);
                saveMonitorCapabilitiesToCache();
                saveMangoMonitorsToCache(caps, rawArr);
                Qt.callLater(() => {
                    checkEdidHdrSupport();
                });
            } catch (e2) {
                console.warn("Failed to parse wlr-randr JSON:", e2);
                displayConfigTab.monitorCapabilities = {
                };
                displayConfigTab.rawMonitorData = [];
            }
        }

        stdout: StdioCollector {
        }

    }

    // Dedicated process for auto-create path — never races with loadMangoWlrRandrProcess.
    // Fired by loadMonitorsFromQuickshellScreens and by Auto Detect button.
    Process {
        id: mangoAutoCreateProcess

        command: ["wlr-randr", "--json"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                console.warn("mangoAutoCreateProcess: wlr-randr failed, exit", exitCode);
                displayConfigTab.loading = false;
                return;
            }
            try {
                var rootJ = JSON.parse(stdout.text);
                var outs = displayConfigTab.normalizeWlrRandrOutputs(rootJ);
                var caps = {};
                var rawArr = [];
                for (var oi = 0; oi < outs.length; oi++) {
                    var wlrOut = outs[oi];
                    var oname = wlrOut.name || "OUT" + oi;
                    var modes = wlrOut.modes || [];
                    var refreshRates = [];
                    var resolutions = [];
                    var resolutionRefreshMap = {};
                    for (var mj = 0; mj < modes.length; mj++) {
                        var md = modes[mj];
                        var mw = md.width || 0;
                        var mh = md.height || 0;
                        var mref = displayConfigTab.refreshMhzToHz(md.refresh || 0);
                        var res = mw + "x" + mh;
                        if (mref > 0 && !refreshRates.includes(mref)) refreshRates.push(mref);
                        if (mw && mh && !resolutions.includes(res)) resolutions.push(res);
                        if (!resolutionRefreshMap[res]) resolutionRefreshMap[res] = [];
                        if (mref > 0 && !resolutionRefreshMap[res].includes(mref))
                            resolutionRefreshMap[res].push(mref);
                    }
                    refreshRates.sort(function(a, b) { return b - a; });
                    resolutions.sort(function(a, b) {
                        var ap = a.split('x'), bp = b.split('x');
                        return (parseInt(bp[0]) * parseInt(bp[1])) - (parseInt(ap[0]) * parseInt(ap[1]));
                    });
                    for (var rk in resolutionRefreshMap)
                        resolutionRefreshMap[rk].sort(function(a, b) { return b - a; });
                    var rect = wlrOut.rect || {};
                    var cm = wlrOut.current_mode || wlrOut.mode || {};
                    var cw = cm.width || rect.width || 0;
                    var ch = cm.height || rect.height || 0;
                    var curHz = displayConfigTab.refreshMhzToHz(cm.refresh || 0);
                    var vrrCap = wlrOut.adaptive_sync === true || wlrOut.adaptive_sync === 1;
                    caps[oname] = {
                        "refreshRates": refreshRates,
                        "resolutions": resolutions,
                        "resolutionRefreshMap": resolutionRefreshMap,
                        "availableModes": modes,
                        "vrr": vrrCap,
                        "hdr": false,
                        "hdrFromEdid": false,
                        "currentMode": cm,
                        "width": cw,
                        "height": ch,
                        "refresh": curHz,
                        "scale": wlrOut.scale !== undefined ? wlrOut.scale : 1,
                        "description": wlrOut.description || "",
                        "make": wlrOut.make || "",
                        "model": wlrOut.model || "",
                        "transform": displayConfigTab.wlrTransformToHyprIndex(wlrOut.transform),
                        "disabled": wlrOut.enabled === false,
                        "currentFormat": "",
                        "mirrorOf": "none",
                        "colorManagementPreset": "",
                        "sdrBrightness": 1,
                        "sdrSaturation": 1,
                        "dpmsStatus": wlrOut.enabled !== false,
                        "focused": false
                    };
                    rawArr.push({
                        "name": oname,
                        "description": wlrOut.description || "",
                        "width": cw,
                        "height": ch,
                        "refreshRate": curHz
                    });
                }
                // Push caps into UI so dropdowns have real data immediately.
                displayConfigTab.monitorCapabilities = caps;
                displayConfigTab.rawMonitorData = rawArr;
                // Save mango-monitors.json — full capabilities for the UI.
                saveMangoMonitorsToCache(caps, rawArr);
                // Backfill refresh rate + resolution on monitors that came from
                // Quickshell.screens (which has no refresh rate info).
                var updatedList = displayConfigTab.monitors.slice();
                var anyChanged = false;
                for (var bi = 0; bi < updatedList.length; bi++) {
                    var bmon = updatedList[bi];
                    var bcap = caps[bmon.name];
                    if (!bcap) continue;
                    var changed = {};
                    if (!(parseFloat(bmon.refreshRate) > 0)) {
                        var hz = bcap.refresh > 0 ? bcap.refresh
                               : (bcap.refreshRates.length > 0 ? bcap.refreshRates[0] : 0);
                        if (hz > 0) { changed.refreshRate = hz.toString(); anyChanged = true; }
                    }
                    if ((!bmon.resolution || bmon.resolution === "0x0") && bcap.width > 0)
                        changed.resolution = bcap.width + "x" + bcap.height;
                    if (Object.keys(changed).length > 0)
                        updatedList[bi] = Object.assign({}, bmon, changed);
                }
                if (anyChanged) displayConfigTab.monitors = updatedList;
                displayConfigTab.loading = false;
                // Write monitors.conf with complete data.
                Qt.callLater(() => { displayConfigTab.saveMonitorsConf(); });
                if (typeof ToastService !== "undefined")
                    ToastService.showInfo("Monitors detected — monitors.conf and mango-monitors.json created");
            } catch (e) {
                console.warn("mangoAutoCreateProcess: failed to parse wlr-randr JSON:", e);
            }
        }

        stdout: StdioCollector {}
    }

    // Dedicated process for auto-create path on niri — never races with loadNiriCapabilitiesProcess.
    // Fired by loadMonitorsFromNiri() and by Auto Detect button.
    Process {
        id: niriAutoCreateProcess

        command: ["niri", "msg", "-j", "outputs"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                console.warn("niriAutoCreateProcess: niri msg failed, exit", exitCode);
                displayConfigTab.loading = false;
                return;
            }
            try {
                var json = JSON.parse(stdout.text);
                var caps = {};
                var monitors = [];

                for (var outputName in json) {
                    var output = json[outputName];
                    if (!output) continue;

                    var refreshRates = [];
                    var resolutions = [];
                    var resolutionRefreshMap = {};
                    if (output.modes && Array.isArray(output.modes)) {
                        for (var j = 0; j < output.modes.length; j++) {
                            var mode = output.modes[j];
                            var width = mode.width || 0;
                            var height = mode.height || 0;
                            var refresh = mode.refresh_rate || 0;
                            var res = width + "x" + height;
                            var refreshHz = refresh / 1000;
                            if (!refreshRates.includes(refreshHz))
                                refreshRates.push(refreshHz);
                            if (!resolutions.includes(res))
                                resolutions.push(res);
                            if (!resolutionRefreshMap[res])
                                resolutionRefreshMap[res] = [];
                            if (!resolutionRefreshMap[res].includes(refreshHz))
                                resolutionRefreshMap[res].push(refreshHz);
                        }
                    }
                    refreshRates.sort(function(a, b) { return b - a; });
                    resolutions.sort(function(a, b) {
                        var aParts = a.split('x');
                        var bParts = b.split('x');
                        return (parseInt(bParts[0]) * parseInt(bParts[1])) - (parseInt(aParts[0]) * parseInt(aParts[1]));
                    });
                    for (var res in resolutionRefreshMap)
                        resolutionRefreshMap[res].sort(function(a, b) { return b - a; });

                    var modeIdx = typeof output.current_mode === 'number' ? output.current_mode : -1;
                    var currentMode = (modeIdx >= 0 && output.modes && output.modes[modeIdx]) ? output.modes[modeIdx] : {};
                    var logical = output.logical || {};
                    var width = currentMode.width || 0;
                    var height = currentMode.height || 0;
                    var refresh = currentMode.refresh_rate || 0;

                    var transformMap = {"Normal":"0","90":"1","180":"2","270":"3","Flipped":"4","Flipped90":"5","Flipped180":"6","Flipped270":"7"};
                    var transformStr = transformMap[logical.transform] || "0";

                    caps[outputName] = {
                        "refreshRates": refreshRates,
                        "resolutions": resolutions,
                        "resolutionRefreshMap": resolutionRefreshMap,
                        "availableModes": output.modes || [],
                        "vrr": output.vrr_supported ? output.vrr_enabled : null,
                        "hdr": false,
                        "hdrFromEdid": false,
                        "currentMode": currentMode,
                        "width": width,
                        "height": height,
                        "refresh": refresh ? (refresh / 1000) : 0,
                        "scale": logical.scale || 1,
                        "description": output.description || "",
                        "make": output.make || "",
                        "model": output.model || "",
                        "transform": logical.transform || "Normal",
                        "disabled": !output.logical,
                        "currentFormat": "",
                        "mirrorOf": "none",
                        "colorManagementPreset": "",
                        "sdrBrightness": 1,
                        "sdrSaturation": 1,
                        "sdrMinLuminance": 0,
                        "sdrMaxLuminance": 0,
                        "dpmsStatus": true,
                        "focused": output.current_workspace !== undefined
                    };

                    monitors.push({
                        "name": outputName,
                        "resolution": (width && height) ? width + "x" + height : "",
                        "position": (logical.x !== undefined && logical.y !== undefined) ? logical.x + "x" + logical.y : "",
                        "scale": logical.scale ? logical.scale.toString() : "1",
                        "refreshRate": refresh ? (refresh / 1000).toFixed(3) : "",
                        "transform": transformStr,
                        "disabled": !output.logical,
                        "bitdepth": "",
                        "cm": "",
                        "sdrbrightness": 1,
                        "sdrsaturation": 1,
                        "sdr_eotf": 0,
                        "vrr": output.vrr_enabled ? "1" : "0",
                        "custom": "",
                        "mirror": "",
                        "supports_wide_color": 0,
                        "supports_hdr": false,
                        "hdr_depth": 2,
                        "sdr_min_luminance": 0,
                        "sdr_max_luminance": 200,
                        "min_luminance": 0,
                        "max_luminance": 0,
                        "max_avg_luminance": 0,
                        "isV2": true
                    });
                }

                displayConfigTab.monitorCapabilities = caps;
                saveNiriMonitorsToCache(json);
                saveMonitorCapabilitiesToCache();
                displayConfigTab.monitors = monitors;
                displayConfigTab.originalContent = "";
                displayConfigTab.loading = false;
                displayConfigTab.hasUnsavedChanges = false;

                Qt.callLater(() => { displayConfigTab.saveMonitorsConf(); });
                if (typeof ToastService !== "undefined")
                    ToastService.showInfo("Monitors detected — outputs.kdl and niri-monitors.json created");
            } catch (e) {
                console.warn("niriAutoCreateProcess: failed to parse niri outputs:", e);
            }
        }

        stdout: StdioCollector {}
    }

    Process {
        id: reloadMangoProcess

        command: ["mmsg", "dispatch", "reload_config"]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                if (typeof ToastService !== "undefined")
                    ToastService.showInfo("Mango configuration reloaded");

                loadMonitorCapabilities();
            } else {
                if (typeof ToastService !== "undefined")
                    ToastService.showError("Failed to reload Mango configuration");

            }
        }

    }

    Process {
        id: edidCheckProcess

        property string monitorName: ""
        property int monitorIndex: -1

        running: false
        onExited: function(exitCode) {
            if (!monitorName)
                return ;

            var output = stdout.text.trim().toUpperCase();
            if (output.includes("HDR")) {
                var caps = Object.assign({
                }, displayConfigTab.monitorCapabilities);
                if (caps[monitorName]) {
                    caps[monitorName].hdr = true;
                    caps[monitorName].hdrFromEdid = true;
                    displayConfigTab.monitorCapabilities = caps;
                    Qt.callLater(() => {
                        saveMonitorCapabilitiesToCache();
                    });
                } else {
                    caps[monitorName] = {
                        "hdr": true,
                        "hdrFromEdid": true,
                        "refreshRates": [],
                        "resolutions": [],
                        "resolutionRefreshMap": {
                        },
                        "vrr": false
                    };
                    displayConfigTab.monitorCapabilities = caps;
                    Qt.callLater(() => {
                        saveMonitorCapabilitiesToCache();
                    });
                }
            }
        }

        stdout: StdioCollector {
        }

    }

    FileView {
        id: capabilitiesCacheFile

        path: displayConfigTab.capabilitiesCachePath
        blockWrites: true
        blockLoading: false
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                var cached = JSON.parse(text());
                if (cached && typeof cached === 'object') {
                    if (cached.rawData) {
                        displayConfigTab.rawMonitorData = cached.rawData;
                        var previousSetup = {
                            "count": cached.rawData.length,
                            "monitors": []
                        };
                        for (var i = 0; i < cached.rawData.length; i++) {
                            var monitor = cached.rawData[i];
                            previousSetup.monitors.push({
                                "name": monitor.name,
                                "description": monitor.description,
                                "width": monitor.width,
                                "height": monitor.height,
                                "refresh": monitor.refreshRate
                            });
                        }
                        previousSetup.monitors.sort(function(a, b) {
                            return a.name.localeCompare(b.name);
                        });
                        displayConfigTab.previousMonitorSetup = previousSetup;
                    }
                    if (cached.processedData)
                        displayConfigTab.monitorCapabilities = cached.processedData;
                    else if (cached.refreshRates || cached.resolutions)
                        displayConfigTab.monitorCapabilities = cached;
                }
            } catch (e) {
                displayConfigTab.monitorCapabilities = {
                };
                displayConfigTab.rawMonitorData = [];
                displayConfigTab.previousMonitorSetup = null;
            }
        }
        onLoadFailed: {
            displayConfigTab.monitorCapabilities = {
            };
            displayConfigTab.rawMonitorData = [];
        }
    }

    Process {
        id: ensureCapabilitiesDirProcess

        command: ["mkdir", "-p"]
        running: false
        onExited: (exitCode) => {
            if (pendingCapabilitiesContent !== "") {
                touchCapabilitiesFileProcess.command = ["touch", capabilitiesCachePath];
                touchCapabilitiesFileProcess.running = true;
            }
        }
    }

    Process {
        id: touchCapabilitiesFileProcess

        command: ["touch"]
        running: false
        onExited: (exitCode) => {
            if (pendingCapabilitiesContent !== "") {
                saveCapabilitiesCacheFile.path = "";
                Qt.callLater(() => {
                    saveCapabilitiesCacheFile.path = capabilitiesCachePath;
                    Qt.callLater(() => {
                        saveCapabilitiesCacheFile.setText(pendingCapabilitiesContent);
                    });
                });
            }
        }
    }

    FileView {
        id: saveCapabilitiesCacheFile

        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true
        onSaved: {
            pendingCapabilitiesContent = "";
        }
        onSaveFailed: (error) => {
            pendingCapabilitiesContent = "";
        }
    }

    Process {
        id: ensureNiriMonitorsDirProcess

        command: ["mkdir", "-p"]
        running: false
        onExited: (exitCode) => {
            if (pendingNiriMonitorsContent !== "") {
                touchNiriMonitorsFileProcess.command = ["touch", niriMonitorsCachePath];
                touchNiriMonitorsFileProcess.running = true;
            }
        }
    }

    Process {
        id: touchNiriMonitorsFileProcess

        command: ["touch"]
        running: false
        onExited: (exitCode) => {
            if (pendingNiriMonitorsContent !== "") {
                saveNiriMonitorsFile.path = "";
                Qt.callLater(() => {
                    saveNiriMonitorsFile.path = niriMonitorsCachePath;
                    Qt.callLater(() => {
                        saveNiriMonitorsFile.setText(pendingNiriMonitorsContent);
                    });
                });
            }
        }
    }

    FileView {
        id: saveNiriMonitorsFile

        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true
        onSaved: {
            pendingNiriMonitorsContent = "";
        }
        onSaveFailed: (error) => {
            pendingNiriMonitorsContent = "";
        }
    }

    // ── mango-monitors.json save pipeline ────────────────────────────────────
    // mkdir -p  →  touch  →  FileView.setText
    Process {
        id: ensureMangoMonitorsDirProcess

        command: ["mkdir", "-p"]
        running: false
        onExited: (exitCode) => {
            if (pendingMangoMonitorsContent !== "") {
                touchMangoMonitorsFileProcess.command = ["touch", mangoMonitorsCachePath];
                touchMangoMonitorsFileProcess.running = true;
            }
        }
    }

    Process {
        id: touchMangoMonitorsFileProcess

        command: ["touch"]
        running: false
        onExited: (exitCode) => {
            if (pendingMangoMonitorsContent !== "") {
                saveMangoMonitorsFile.path = "";
                Qt.callLater(() => {
                    saveMangoMonitorsFile.path = mangoMonitorsCachePath;
                    Qt.callLater(() => {
                        saveMangoMonitorsFile.setText(pendingMangoMonitorsContent);
                    });
                });
            }
        }
    }

    FileView {
        id: saveMangoMonitorsFile

        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true
        onSaved: {
            pendingMangoMonitorsContent = "";
        }
        onSaveFailed: (error) => {
            console.warn("Failed to save mango-monitors.json:", error);
            pendingMangoMonitorsContent = "";
        }
    }

    // ── hypr-monitors.json save pipeline ────────────────────────────────────────
    Process {
        id: ensureHyprMonitorsDirProcess

        command: ["mkdir", "-p"]
        running: false
        onExited: (exitCode) => {
            if (pendingHyprMonitorsContent !== "") {
                touchHyprMonitorsFileProcess.command = ["touch", hyprMonitorsCachePath];
                touchHyprMonitorsFileProcess.running = true;
            }
        }
    }

    Process {
        id: touchHyprMonitorsFileProcess

        command: ["touch"]
        running: false
        onExited: (exitCode) => {
            if (pendingHyprMonitorsContent !== "") {
                saveHyprMonitorsFile.path = "";
                Qt.callLater(() => {
                    saveHyprMonitorsFile.path = hyprMonitorsCachePath;
                    Qt.callLater(() => {
                        saveHyprMonitorsFile.setText(pendingHyprMonitorsContent);
                    });
                });
            }
        }
    }

    FileView {
        id: saveHyprMonitorsFile

        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true
        onSaved: {
            pendingHyprMonitorsContent = "";
        }
        onSaveFailed: (error) => {
            console.warn("Failed to save hypr-monitors.json:", error);
            pendingHyprMonitorsContent = "";
        }
    }

    // ── monitors.conf save pipeline ───────────────────────────────────────────
    Process {
        id: ensureDirProcess

        command: ["mkdir", "-p"]
        running: false
        onExited: (exitCode) => {
            if (pendingSaveContent !== "") {
                touchFileProcess.command = ["touch", monitorsConfPath];
                touchFileProcess.running = true;
            }
        }
    }

    Process {
        id: touchFileProcess

        command: ["touch"]
        running: false
        onExited: (exitCode) => {
            if (pendingSaveContent !== "") {
                saveMonitorsFile.path = "";
                Qt.callLater(() => {
                    saveMonitorsFile.path = monitorsConfPath;
                    Qt.callLater(() => {
                        saveMonitorsFile.setText(pendingSaveContent);
                    });
                });
            }
        }
    }

    FileView {
        id: saveMonitorsFile

        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true
        onSaved: {
            hasUnsavedChanges = false;
            if (typeof ToastService !== "undefined")
                ToastService.showInfo("Monitor configuration saved successfully");

            Qt.callLater(() => {
                monitorsFile.reload();
            });
            if (CompositorService.isNiri)
                reloadNiriProcess.running = true;
            else if (CompositorService.isMango)
                reloadMangoProcess.running = true;
            else
                reloadHyprlandProcess.running = true;
            pendingSaveContent = "";
        }
        onSaveFailed: (error) => {
            if (typeof ToastService !== "undefined")
                ToastService.showError("Failed to save monitor configuration: " + (error || "Unknown error"));

            pendingSaveContent = "";
        }
    }

    Process {
        id: reloadHyprlandProcess

        command: ["hyprctl", "reload"]
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                if (typeof ToastService !== "undefined")
                    ToastService.showInfo("Hyprland configuration reloaded");

                loadMonitorCapabilities();
            } else {
                if (typeof ToastService !== "undefined")
                    ToastService.showError("Failed to reload Hyprland configuration");

            }
        }
    }

    Process {
        id: reloadNiriProcess

        command: ["niri", "msg", "action", "reload-config-or-panic"]
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                if (typeof ToastService !== "undefined")
                    ToastService.showInfo("niri configuration reloaded");

                loadMonitorCapabilities();
            } else {
                if (typeof ToastService !== "undefined")
                    ToastService.showError("Failed to reload niri configuration");

            }
        }
    }

    FileView {
        id: wipeMonitorsConfFile

        blockWrites: false
        blockLoading: true
        atomicWrites: true
        printErrors: true
        onSaved: {
            console.log("Successfully wiped monitors.conf");
            if (typeof ToastService !== "undefined")
                ToastService.showInfo("Monitor configuration has been reset due to monitor changes. Please reconfigure your displays.");

            Qt.callLater(() => {
                displayConfigTab.loadMonitorsConf();
            });
        }
        onSaveFailed: (error) => {
            console.error("Failed to wipe monitors.conf:", error);
            if (typeof ToastService !== "undefined")
                ToastService.showError("Failed to reset monitor configuration: " + (error || "Unknown error"));

        }
    }

    FileView {
        id: mangoMiscFile

        path: displayConfigTab.mangoMiscConfPath
        blockWrites: true
        blockLoading: false
        atomicWrites: true
        printErrors: false

        onLoaded: {
            displayConfigTab.parseHdrDepthFromMisc(text())
        }

        onLoadFailed: {}
    }

    Process {
        id: updateHdrDepthProcess

        command: ["true"]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0)
                mangoMiscFile.reload()
        }
    }

    EHFlickable {
        id: flickable

        anchors.fill: parent
        anchors.topMargin: Theme.spacingM
        anchors.bottomMargin: Theme.spacingS
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn

            width: parent.width - Theme.spacingL * 2
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL
            topPadding: 4

            // ============================================
            // SECTION 1: Monitor Arrangement (Visual Canvas)
            // ============================================
            StyledRect {
                width: parent.width
                height: arrangementSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.15)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1
                visible: displayConfigTab.monitors.length > 0 && !displayConfigTab.loading

                Column {
                    id: arrangementSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Header with icon and title
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "monitor"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Monitor Arrangement"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Drag monitors to reposition - scroll to zoom"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                        }

                    }

                    // Monitor Canvas
                    MonitorArrangementWidget {
                        id: arrangementWidget

                        width: parent.width
                        monitors: displayConfigTab.monitors
                        monitorCapabilities: displayConfigTab.monitorCapabilities
                        selectedMonitor: displayConfigTab.selectedMonitor
                        onMonitorSelected: function(monitorName) {
                            displayConfigTab.selectedMonitor = monitorName;
                        }
                        onPositionsBatchChanged: function(batch) {
                            displayConfigTab.applyMonitorPositionsBatch(batch);
                        }
                        onAutoDetectRequested: {
                            // Auto Detect button: always re-run detection, regenerate
                            // cache and config.
                            if (CompositorService.isNiri) {
                                displayConfigTab.loading = true;
                                if (!niriAutoCreateProcess.running)
                                    niriAutoCreateProcess.running = true;
                            } else if (CompositorService.isMango) {
                                displayConfigTab.loading = true;
                                if (!mangoAutoCreateProcess.running)
                                    mangoAutoCreateProcess.running = true;
                            }
                        }
                    }

                }

            }

            // ============================================
            // Loading / Empty States
            // ============================================
            StyledText {
                text: "Loading monitors..."
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                visible: displayConfigTab.loading
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            StyledText {
                text: displayConfigTab.monitors.length === 0 && !displayConfigTab.loading ? (CompositorService.isNiri ? "No monitors found. Make sure niri is running and monitors are configured." : CompositorService.isMango ? "No monitors found. Ensure Mango is running and ~/.config/mango/monitors.conf is readable, or check Quickshell screen detection." : "No monitors found. Make sure Hyprland is running and monitors are configured.") : ""
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                visible: displayConfigTab.monitors.length === 0 && !displayConfigTab.loading
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // ============================================
            // SECTION 2: Monitor Configuration Cards
            // ============================================
            StyledRect {
                width: parent.width
                height: monitorsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.15)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                border.width: 1
                visible: displayConfigTab.monitors.length > 0 && !displayConfigTab.loading

                Column {
                    id: monitorsSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    // Header with icon and title
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        EHIcon {
                            name: "tune"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Monitor Configuration"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Configure resolution, refresh rate, scale, and color settings"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                        }

                    }

                    // Show All button (when a specific monitor is selected)
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: displayConfigTab.selectedMonitor !== ""

                        StyledRect {
                            height: 36
                            width: showAllButtonText.implicitWidth + Theme.spacingL * 2
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                            border.color: Theme.primary
                            border.width: 1

                            StyledText {
                                id: showAllButtonText

                                anchors.centerIn: parent
                                text: "Show All Monitors"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primary
                            }

                            StateLayer {
                                stateColor: Theme.primary
                                cornerRadius: parent.radius
                                onClicked: {
                                    displayConfigTab.selectedMonitor = "";
                                }
                            }

                        }

                    }

                    // Monitor Cards
                    Repeater {
                        model: displayConfigTab.getFilteredMonitors()

                        delegate: MonitorConfigWidget {
                            width: parent.width
                            monitorData: modelData
                            monitorCapabilities: displayConfigTab.monitorCapabilities[modelData.name] || {
                            }
                            mangoHdrDepth: displayConfigTab.mangoHdrDepth
                            onSettingChanged: function(setting, value) {
                                displayConfigTab.applyMonitorSetting(modelData.name, setting, value);
                            }
                            onMangoGlobalSettingChanged: function(key, value) {
                                if (key === "hdr_depth") {
                                    displayConfigTab.mangoHdrDepth = value;
                                    displayConfigTab.writeHdrDepthToMisc(value);
                                }
                            }
                        }

                    }

                }

            }


        }

    }

}
