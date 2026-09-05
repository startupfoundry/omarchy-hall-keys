import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
    id: root
    moduleName: "io.github.startupfoundry.hall-keys"

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    // Persist settings on this widget's shell.json entry in one write.
    function updateSettings(changes) {
        var next = Object.assign({}, root.settings)
        for (var key in changes) next[key] = changes[key]
        root.settings = next
        if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
            root.bar.shell.updateEntryInline(root.moduleName, root.settings)
    }

    function updateSetting(key, value) {
        var changes = {}
        changes[key] = value
        updateSettings(changes)
    }

    function open() {
        if (panelLoader.item) panelLoader.item.open()
        keys.refresh()
    }

    function close() {
        if (panelLoader.item) panelLoader.item.close()
    }

    function toggle() {
        if (panelLoader.item) panelLoader.item.toggle()
        keys.refresh()
    }

    // One active choice: a profile, or the Omarchy theme. Picking a profile
    // hands lighting back to it; the theme is switched off first so the
    // reset reaches the board before the profile change does.
    function chooseProfile(index) {
        if (!keys.connected) return
        if (keys.themeLighting) updateSetting("themeLighting", false)
        keys.setProfile(index)
    }

    function cycleProfile(step) {
        if (!keys.connected || keys.profileCount < 1) return
        var n = keys.profileCount
        chooseProfile(((keys.profileIndex + step) % n + n) % n)
    }

    function closeForPopoutSwitch() {
        if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
    }

    function injectPanel() {
        if (!panelLoader.item) return
        panelLoader.item.bar = root.bar
        panelLoader.item.anchorItem = button
        panelLoader.item.hostWidget = root
        panelLoader.item.keys = keys
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: injectPanel()

    Service {
        id: keys
        settings: root.settings
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        active: false
        useActiveColor: false
        dimmed: !keys.connected
        tooltipText: Model.barTooltip(keys, root.settings)
        text: Model.KEYBOARD_GLYPH
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton) root.toggle()
        }
        onWheelMoved: function(delta) {
            root.cycleProfile(delta > 0 ? -1 : 1)
        }
    }
}
