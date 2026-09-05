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

    // Persist one setting on this widget's shell.json entry.
    function updateSetting(key, value) {
        var next = Object.assign({}, root.settings)
        next[key] = value
        root.settings = next
        if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
            root.bar.shell.updateEntryInline(root.moduleName, root.settings)
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

    // Open the panel straight into rename mode. Reachable over IPC:
    //   omarchy-shell shell call io.github.startupfoundry.hall-keys renameProfiles ""
    function renameProfiles() {
        open()
        if (panelLoader.item) Qt.callLater(function() { panelLoader.item.startRenaming() })
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
            keys.cycleProfile(delta > 0 ? -1 : 1)
        }
    }
}
