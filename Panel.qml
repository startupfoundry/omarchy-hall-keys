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

    // Whatever ends rename mode (check button, Enter on the last field, Esc,
    // the panel closing) saves every field in one settings write first.
    function stopRenaming() {
        if (renaming) commitNames()
        renaming = false
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    function commitNames() {
        var grid = nameGridLoader.item
        if (!grid || !hostWidget || typeof hostWidget.updateSettings !== "function") return
        var names = grid.names()
        var changes = {}
        var dirty = false
        for (var i = 0; i < names.length; i++) {
            var clean = Model.cleanText(names[i], "", 24)
            if (clean === Model.profileName(root.widgetSettings, i)) continue
            changes["profile" + (i + 1) + "Name"] = clean
            dirty = true
        }
        if (dirty) hostWidget.updateSettings(changes)
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

    function chooseProfile(index) {
        if (hostWidget && typeof hostWidget.chooseProfile === "function") hostWidget.chooseProfile(index)
        else if (keys) keys.setProfile(index)
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

    onOpenedChanged: {
        if (opened) {
            if (keys) keys.refresh()
            Qt.callLater(function() { keyCatcher.forceActiveFocus() })
        } else if (renaming) {
            stopRenaming()
        }
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
                if (n >= 1 && n <= root.profileCount) root.chooseProfile(n - 1)
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
                                selected: index === root.profileIndex && !root.themeLighting
                                bordered: true
                                foreground: root.foreground
                                fontFamily: root.fontFamily
                                onClicked: root.chooseProfile(index)
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

                            function names() {
                                var out = []
                                for (var i = 0; i < nameRepeater.count; i++) {
                                    var field = nameRepeater.itemAt(i)
                                    out.push(field ? field.text : "")
                                }
                                return out
                            }

                            Repeater {
                                id: nameRepeater
                                model: root.profileCount
                                delegate: TextField {
                                    required property int index
                                    width: nameGrid.cellWidth
                                    placeholderText: "Profile " + (index + 1)
                                    maximumLength: 24
                                    foreground: root.foreground
                                    // Seeded once, not bound: a live binding would clobber typing.
                                    Component.onCompleted: text = Model.profileName(root.widgetSettings, index)
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

                    // The fifth choice: every key in the theme color. Selected here means
                    // no profile shows as selected above; picking a profile switches back.
                    BorderSurface {
                        id: themeOption
                        width: parent.width
                        radius: Style.cornerRadius
                        readonly property bool on: root.themeLighting
                        readonly property bool hot: themeMouse.containsMouse
                        readonly property color textColor: on ? Style.selectedStateColor(root.foreground, Color.accent) : root.foreground
                        readonly property var hoverSpec: Border.controlSpec("hover-cursor", root.foreground, Color.accent)
                        readonly property var selectedSpec: Border.controlHasWidth("selected")
                            ? Border.controlSpec("selected", root.foreground, Color.accent)
                            : Border.controlSpec("normal", root.foreground, Color.accent)
                        readonly property var normalSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                        readonly property real reservedTop: Math.max(Border.top(hoverSpec), Border.top(selectedSpec), Border.top(normalSpec))
                        readonly property real reservedBottom: Math.max(Border.bottom(hoverSpec), Border.bottom(selectedSpec), Border.bottom(normalSpec))
                        implicitHeight: themeRow.implicitHeight + Style.spacing.controlPaddingY * 2 + reservedTop + reservedBottom
                        borderSpec: hot ? hoverSpec : (on ? selectedSpec : normalSpec)
                        color: themeMouse.pressed ? Style.pressedFillFor(root.foreground, Color.accent)
                            : hot ? Style.hoverFillFor(root.foreground, Color.accent)
                            : on ? Style.selectedFillFor(root.foreground, Color.accent)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            id: themeRow
                            anchors.centerIn: parent
                            spacing: Style.spacing.controlGap

                            Rectangle {
                                width: Style.font.body + Style.space(2)
                                height: width
                                radius: Math.max(2, Style.cornerRadius / 2)
                                color: Model.isHexColor(root.themeColor) ? root.themeColor : "transparent"
                                border.width: 1
                                border.color: themeOption.textColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                textFormat: Text.PlainText
                                text: "Omarchy Theme"
                                color: themeOption.textColor
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                                font.bold: themeOption.on
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: themeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setThemeLighting(!root.themeLighting)
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.renaming
                            ? "Enter saves and moves on, Esc cancels. Empty means the default name."
                            : "Pick a profile or the theme. 1-4 or scroll to switch, pencil to rename."
                        color: root.foreground
                        opacity: 0.6
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
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
                        tooltipText: "Re-read the keyboard and re-apply the theme color if it is on"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        bordered: true
                        onClicked: if (root.keys) root.keys.resync()
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
