import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
    id: root
    moduleName: "io.github.startupfoundry.hall-keys"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property var keys: null

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color urgent: bar ? bar.urgent : Color.urgent
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property var widgetSettings: hostWidget ? hostWidget.settings : ({})

    readonly property bool connected: keys ? keys.connected : false
    readonly property string access: keys ? keys.access : "absent"
    readonly property string model: keys ? keys.model : ""
    readonly property string firmware: keys ? keys.firmware : ""
    readonly property string protocol: keys ? keys.protocol : ""
    readonly property int profileIndex: keys ? keys.profileIndex : -1
    readonly property int profileCount: keys ? keys.profileCount : 4
    readonly property string themeColor: keys ? keys.themeColor : ""
    readonly property bool themeLighting: keys ? keys.themeLighting : false
    readonly property string lastError: keys ? keys.lastError : ""
    readonly property bool granting: keys ? keys.granting : false

    // Rename mode swaps the profile buttons for text fields. While it is on,
    // the key catcher is blocked so typing reaches the fields.
    property bool renaming: false

    function startRenaming() {
        if (!connected) return
        renaming = true
    }

    function stopRenaming() {
        renaming = false
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    function commitName(index, text) {
        if (!hostWidget || typeof hostWidget.updateSetting !== "function") return
        var clean = Model.cleanText(text, "", 24)
        if (clean === Model.profileName(root.widgetSettings, index)) return
        hostWidget.updateSetting("profile" + (index + 1) + "Name", clean)
    }

    function open() {
        root.controller.show()
        if (keys) keys.refresh()
    }

    function close() {
        root.controller.hide()
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction)
        return false
    }

    function setThemeLighting(on) {
        if (hostWidget && typeof hostWidget.updateSetting === "function")
            hostWidget.updateSetting("themeLighting", on)
    }

    function heroTitle() {
        if (connected) return model !== "" ? model : "Wooting keyboard"
        if (access === "denied") return "Keyboard access needed"
        if (access === "unsupported") return model !== "" ? model : "Unsupported keyboard"
        return "No keyboard found"
    }

    function heroMeta() {
        if (connected) return firmware !== "" ? "Firmware " + firmware : ""
        return Model.accessHint(access)
    }

    onOpenedChanged: if (opened) {
        if (keys) keys.refresh()
        renaming = false
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(360))
        contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(640))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            blocked: root.renaming
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }
            onTextKey: function(text) {
                var n = Number(text)
                if (n >= 1 && n <= root.profileCount && root.keys) root.keys.setProfile(n - 1)
            }

            Column {
                id: content
                width: parent.width
                spacing: Style.space(12)

                PanelHero {
                    width: parent.width
                    title: root.heroTitle()
                    meta: root.heroMeta()
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    iconComponent: Component {
                        Text {
                            text: Model.KEYBOARD_GLYPH
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.display
                        }
                    }
                }

                // Boards still on the classic protocol: point at Wootility for firmware.
                Text {
                    width: parent.width
                    visible: root.connected && root.protocol === "classic"
                    text: "This firmware speaks Wooting's classic protocol. Hall Keys works with it, but newer firmware gets the most testing. Open Wootility below to check for an update."
                    color: root.foreground
                    opacity: 0.7
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }

                // Profiles
                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: root.connected

                    Item {
                        width: parent.width
                        height: renameButton.height

                        PanelSectionHeader {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Profiles"
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                        }

                        PanelActionButton {
                            id: renameButton
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            iconText: root.renaming ? "󰄬" : "󰏫"
                            tooltipText: root.renaming ? "Done renaming" : "Rename profiles"
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            onClicked: root.renaming ? root.stopRenaming() : root.startRenaming()
                        }
                    }

                    Grid {
                        id: profileGrid
                        visible: !root.renaming
                        width: parent.width
                        columns: 2
                        columnSpacing: Style.space(8)
                        rowSpacing: Style.space(8)
                        readonly property real cellWidth: (width - columnSpacing) / 2

                        Repeater {
                            model: root.profileCount
                            delegate: Button {
                                required property int index
                                width: profileGrid.cellWidth
                                text: Model.profileLabel(root.widgetSettings, index)
                                selected: index === root.profileIndex
                                bordered: true
                                foreground: root.foreground
                                fontFamily: root.fontFamily
                                onClicked: if (root.keys) root.keys.setProfile(index)
                            }
                        }
                    }

                    Loader {
                        id: nameGridLoader
                        width: parent.width
                        active: root.renaming
                        visible: active
                        onLoaded: Qt.callLater(function() { if (item) item.focusFirst() })
                        sourceComponent: Grid {
                            id: nameGrid
                            width: nameGridLoader.width
                            columns: 2
                            columnSpacing: Style.space(8)
                            rowSpacing: Style.space(8)
                            readonly property real cellWidth: (width - columnSpacing) / 2

                            function focusFirst() {
                                var first = nameRepeater.itemAt(0)
                                if (first) { first.forceActiveFocus(); first.selectAll() }
                            }

                            Repeater {
                                id: nameRepeater
                                model: root.profileCount
                                delegate: TextField {
                                    required property int index
                                    width: nameGrid.cellWidth
                                    text: Model.profileName(root.widgetSettings, index)
                                    placeholderText: "Profile " + (index + 1)
                                    maximumLength: 24
                                    foreground: root.foreground
                                    onEditingFinished: root.commitName(index, text)
                                    onAccepted: {
                                        var next = nameRepeater.itemAt(index + 1)
                                        if (next) { next.forceActiveFocus(); next.selectAll() }
                                        else root.stopRenaming()
                                    }
                                    Keys.onEscapePressed: {
                                        text = Model.profileName(root.widgetSettings, index)
                                        root.stopRenaming()
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.renaming
                            ? "Enter saves and moves on, Esc cancels. Empty means the default name."
                            : "Press 1-4 or scroll the bar icon to switch. The pencil renames."
                        color: root.foreground
                        opacity: 0.6
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }
                }

                // Lighting
                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: root.connected

                    PanelSectionHeader {
                        width: parent.width
                        text: "Lighting"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                    }

                    Toggle {
                        width: parent.width
                        label: "Wear the theme"
                        description: (root.themeColor !== ""
                            ? "Every key in " + root.themeColor + ", following theme changes."
                            : "Every key in the theme's keyboard color.")
                            + " A profile switch shows its own lighting briefly."
                        checked: root.themeLighting
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        onClicked: root.setThemeLighting(!root.themeLighting)
                    }

                    Row {
                        spacing: Style.space(8)

                        Rectangle {
                            width: reapplyButton.height
                            height: reapplyButton.height
                            radius: Style.cornerRadius
                            color: Model.isHexColor(root.themeColor) ? root.themeColor : "transparent"
                            border.width: 1
                            border.color: root.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Button {
                            id: reapplyButton
                            text: "Re-apply"
                            tooltipText: "Send the theme color to the keyboard again"
                            enabled: root.themeLighting
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            bordered: true
                            onClicked: if (root.keys) root.keys.paintTheme()
                        }

                        Button {
                            text: "Onboard lighting"
                            tooltipText: "Hand lighting back to the keyboard's own profile"
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            bordered: true
                            onClicked: {
                                root.setThemeLighting(false)
                                if (root.keys) root.keys.resetLighting()
                            }
                        }
                    }
                }

                // Setup
                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: !root.connected

                    PanelSectionHeader {
                        width: parent.width
                        text: "Setup"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                    }

                    Text {
                        width: parent.width
                        visible: root.access === "denied"
                        text: "Linux keeps raw keyboard access private by default. Granting access installs one udev rule so your desktop session can talk to the keyboard. It asks for your password once."
                        color: root.foreground
                        opacity: 0.8
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                    }

                    Button {
                        visible: root.access === "denied"
                        text: root.granting ? "Waiting for password…" : "Grant keyboard access"
                        enabled: !root.granting
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        bordered: true
                        onClicked: if (root.keys) root.keys.grantAccess()
                    }

                    Text {
                        width: parent.width
                        visible: root.access !== "denied"
                        text: Model.accessHint(root.access)
                        color: root.foreground
                        opacity: 0.8
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                    }
                }

                PanelSeparator {
                    width: parent.width
                    foreground: root.foreground
                }

                Row {
                    spacing: Style.space(8)

                    Button {
                        text: "Open Wootility"
                        tooltipText: "Opens wootility.io as an app window. First time: continue past its Linux setup page (already done here), then Find Devices and pick the keyboard."
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        bordered: true
                        onClicked: {
                            root.close()
                            if (root.keys) root.keys.openWootility()
                        }
                    }

                    Button {
                        text: "Refresh"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        bordered: true
                        onClicked: if (root.keys) root.keys.refresh()
                    }
                }

                Text {
                    width: parent.width
                    visible: root.lastError !== "" && !root.connected
                    text: root.lastError
                    color: root.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
