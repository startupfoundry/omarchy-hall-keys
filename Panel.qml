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
    readonly property string serial: keys ? keys.serial : ""
    readonly property int profileIndex: keys ? keys.profileIndex : -1
    readonly property int profileCount: keys ? keys.profileCount : 4
    readonly property string themeColor: keys ? keys.themeColor : ""
    readonly property bool themeLighting: keys ? keys.themeLighting : false
    readonly property string lastError: keys ? keys.lastError : ""
    readonly property bool granting: keys ? keys.granting : false

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

                Text {
                    width: parent.width
                    visible: root.connected && root.serial !== ""
                    text: "Serial " + root.serial
                    color: root.foreground
                    opacity: 0.6
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                }

                // Profiles
                Column {
                    width: parent.width
                    spacing: Style.space(8)
                    visible: root.connected

                    PanelSectionHeader {
                        width: parent.width
                        text: "Profiles"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                    }

                    ButtonGroup {
                        width: parent.width
                        options: Model.profileOptions(root.widgetSettings, root.profileCount)
                        value: String(root.profileIndex)
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        onChanged: function(v) { if (root.keys) root.keys.setProfile(Number(v)) }
                    }

                    Text {
                        width: parent.width
                        text: "Keys 1-4 switch, scrolling the bar icon cycles. Name profiles under Setup › Plugins › Hall Keys."
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
                        description: root.themeColor !== ""
                            ? "Every key lights up in " + root.themeColor + " and follows theme changes."
                            : "Every key lights up in the theme's keyboard color."
                        checked: root.themeLighting
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        onClicked: root.setThemeLighting(!root.themeLighting)
                    }

                    Row {
                        spacing: Style.space(8)

                        Rectangle {
                            width: Style.space(28)
                            height: Style.space(28)
                            radius: Style.cornerRadius
                            color: Model.isHexColor(root.themeColor) ? root.themeColor : "transparent"
                            border.width: 1
                            border.color: root.foreground
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Button {
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
                        tooltipText: "Full configuration in the browser (wootility.io)"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        onClicked: if (root.keys) root.keys.openWootility()
                    }

                    Button {
                        text: "Refresh"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
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
