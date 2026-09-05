import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

// Headless state for one Wooting keyboard: polls the helper, queues actions,
// and keeps the board painted in the theme color when theme lighting is on.
Item {
    id: root

    property var settings: ({})

    property bool connected: false
    property string access: "absent"
    property string devicePath: ""
    property string model: ""
    property string firmware: ""
    property string serial: ""
    property int profileIndex: -1
    property int profileCount: 4
    property string lastError: ""
    property bool busy: false
    property bool granting: false

    // "#rrggbb" from the theme's keyboard.rgb, falling back to the shell accent.
    property string themeColor: ""
    readonly property color accentColor: Color.accent
    readonly property bool themeLighting: Model.settingBool(settings, "themeLighting", false)
    readonly property int pollIntervalSec: Model.settingNumber(settings, "pollInterval", 20, 5, 600)

    readonly property string helperPath: Model.pathFromUrl(Qt.resolvedUrl("bin/hall-keys"))
    readonly property string themeRgbPath: Color.currentThemePath + "/keyboard.rgb"

    property var pending: []

    function refresh() {
        if (!pollProc.running) pollProc.running = true
    }

    function run(args) {
        pending.push(args)
        pump()
    }

    function pump() {
        if (cmdProc.running || pending.length === 0) return
        var args = pending.shift()
        cmdProc.command = [root.helperPath].concat(args)
        root.busy = true
        cmdProc.running = true
    }

    // With theme lighting on, a switch would be invisible on the board: host
    // lighting hides the profile's own colors. So hand lighting back for a
    // moment, let the new profile show itself, then bring the theme back.
    function setProfile(index) {
        if (!connected) return
        index = Math.max(0, Math.min(profileCount - 1, Math.round(index)))
        profileIndex = index          // optimistic; the helper's reply confirms it
        run(["profile", String(index + 1)])
        if (themeLighting) {
            run(["reset"])
            profileShowTimer.restart()
        }
    }

    function cycleProfile(step) {
        if (!connected || profileCount < 1) return
        var n = profileCount
        setProfile(((profileIndex + step) % n + n) % n)
    }

    function paintTheme() {
        if (!Model.isHexColor(themeColor)) return
        run(["paint", themeColor])
    }

    function resetLighting() {
        run(["reset"])
    }

    // Paints go through the timer so a setting flip and a theme reload that
    // land together become one helper call; a reset is immediate.
    function applyLighting() {
        if (themeLighting) repaintTimer.restart()
        else resetLighting()
    }

    function grantAccess() {
        if (grantProc.running) return
        grantProc.command = Model.grantAccessCommand()
        root.granting = true
        grantProc.running = true
    }

    // App-mode window in the default Chromium-based browser, the Omarchy way
    // to run a web app. Wootility needs WebHID, which those browsers have.
    function openWootility() {
        Quickshell.execDetached(["omarchy-launch-webapp", "https://wootility.io"])
    }

    function applyLine(raw) {
        var s = Model.parseStatus(raw)
        var wasConnected = connected
        connected = s.connected
        access = s.access
        devicePath = s.device
        model = s.model
        firmware = s.firmware
        serial = s.serial
        profileCount = s.profileCount
        profileIndex = s.profileIndex
        lastError = s.error
        if (connected && !wasConnected && themeLighting) repaintTimer.restart()
    }

    onThemeLightingChanged: applyLighting()
    onThemeColorChanged: if (themeLighting && connected) repaintTimer.restart()
    onAccentColorChanged: themeFile.reload()

    // The theme's keyboard color. Watched so a theme switch repaints the board.
    FileView {
        id: themeFile
        path: root.themeRgbPath
        watchChanges: true
        printErrors: false
        onLoaded: root.themeColor = Model.normalizeColor(text(), String(root.accentColor))
        onFileChanged: reload()
        onLoadFailed: root.themeColor = Model.normalizeColor("", String(root.accentColor))
    }

    // Theme comes back after the new profile had its moment on the board.
    Timer {
        id: profileShowTimer
        interval: 1500
        repeat: false
        onTriggered: if (root.themeLighting) root.paintTheme()
    }

    // Coalesce bursts (a theme switch touches several files) into one paint.
    Timer {
        id: repaintTimer
        interval: 400
        repeat: false
        onTriggered: root.paintTheme()
    }

    Timer {
        id: pollTimer
        interval: root.pollIntervalSec * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: pollProc
        command: [root.helperPath, "status"]
        stdout: StdioCollector {
            id: pollOut
            waitForEnd: true
            onStreamFinished: root.applyLine((pollOut.text || "").trim())
        }
    }

    Process {
        id: cmdProc
        stdout: StdioCollector {
            id: cmdOut
            waitForEnd: true
            onStreamFinished: {
                root.applyLine((cmdOut.text || "").trim())
                root.busy = false
                root.pump()
            }
        }
    }

    // One polkit prompt; then give udev a moment before checking access again.
    Process {
        id: grantProc
        onExited: function(exitCode, exitStatus) {
            root.granting = false
            settleTimer.restart()
        }
    }

    Timer {
        id: settleTimer
        interval: 1500
        repeat: false
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
