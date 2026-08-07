pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: hdrService

    property bool hdrEnabled: false
    property bool isChecking: false

    function checkHdrState() {
        isChecking = true
        if (typeof CompositorService !== "undefined" && CompositorService.isMango)
            checkMangoProcess.running = true
        else
            checkProcess.running = true
    }

    function toggleHdr() {
        if (typeof CompositorService !== "undefined" && CompositorService.isMango)
            toggleMangoProcess.running = true
        else
            toggleProcess.running = true
    }

    Process {
        id: checkProcess
        command: ["sh", "-c", "grep -q 'cm\\s*=\\s*\"hdr\"' \"$(echo ~)/.config/hypr/monitors.lua\""]
        onExited: (code, status) => {
            isChecking = false
            hdrEnabled = (code === 0)
        }
    }

    Process {
        id: toggleProcess
        command: ["sh", "-c", "python3 \"$(echo ~)/.config/hypr/hyprhdr.py\""]
        onExited: (code, status) => {
            if (code === 0) {
                checkHdrState()
            }
        }
    }

    Process {
        id: checkMangoProcess
        command: ["sh", "-c", "grep -q 'hdr:1' \"$(echo ~)/.config/mango/monitors.conf\" 2>/dev/null"]
        onExited: (code, status) => {
            isChecking = false
            hdrEnabled = (code === 0)
        }
    }

    Process {
        id: toggleMangoProcess
        command: ["sh", "-c", "f=\"$(echo ~)/.config/mango/monitors.conf\"; if [ -f \"$f\" ]; then if grep -q 'hdr:1' \"$f\"; then sed -i 's/hdr:1/hdr:0/g' \"$f\"; else sed -i 's/hdr:0/hdr:1/g' \"$f\"; fi; mmsg dispatch reload_config 2>/dev/null; fi"]
        onExited: (code, status) => {
            checkHdrState()
        }
    }

    Component.onCompleted: {
        checkHdrState()
    }
}
