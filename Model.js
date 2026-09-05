// Model.js - pure helpers for the Hall Keys plugin: parse the helper's JSON,
// sanitize text that came from outside the shell, and build labels.

var UDEV_RULE_PATH = "/etc/udev/rules.d/70-wooting-hidraw-uaccess.rules"
var UDEV_RULE_LINES = [
  "# Installed by the Hall Keys Omarchy plugin.",
  "# Lets the active logged-in user configure Wooting keyboards over hidraw and USB",
  "# (same mechanism systemd uses for other seat devices). Matches the device list",
  "# in Wooting's own Linux udev guide, so Wootility firmware updates work too.",
  "# Current Wooting boards (Two HE, 60HE, 80HE, UwU, ...)",
  "SUBSYSTEM==\"hidraw\", ATTRS{idVendor}==\"31e3\", MODE:=\"0660\", GROUP=\"input\", TAG+=\"uaccess\"",
  "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"31e3\", MODE:=\"0660\", GROUP=\"input\", TAG+=\"uaccess\"",
  "# Wooting One and Two (first generation) and their firmware update mode",
  "SUBSYSTEM==\"hidraw\", ATTRS{idVendor}==\"03eb\", ATTRS{idProduct}==\"ff01\", MODE:=\"0660\", GROUP=\"input\", TAG+=\"uaccess\"",
  "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"03eb\", ATTRS{idProduct}==\"ff01\", MODE:=\"0660\", GROUP=\"input\", TAG+=\"uaccess\"",
  "SUBSYSTEM==\"hidraw\", ATTRS{idVendor}==\"03eb\", ATTRS{idProduct}==\"2402\", MODE:=\"0660\", GROUP=\"input\", TAG+=\"uaccess\"",
  "SUBSYSTEM==\"hidraw\", ATTRS{idVendor}==\"03eb\", ATTRS{idProduct}==\"ff02\", MODE:=\"0660\", GROUP=\"input\", TAG+=\"uaccess\"",
  "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"03eb\", ATTRS{idProduct}==\"ff02\", MODE:=\"0660\", GROUP=\"input\", TAG+=\"uaccess\"",
  "SUBSYSTEM==\"hidraw\", ATTRS{idVendor}==\"03eb\", ATTRS{idProduct}==\"2403\", MODE:=\"0660\", GROUP=\"input\", TAG+=\"uaccess\""
]

var KEYBOARD_GLYPH = "󰌌"   // nf-md-keyboard (U+F030C)

function defaultStatus() {
  return {
    ok: true,
    connected: false,
    access: "absent",
    device: "",
    model: "",
    firmware: "",
    serial: "",
    profileIndex: -1,
    profileCount: 4,
    error: ""
  }
}

// Strip control characters and markup-ish characters from text we did not write.
function cleanText(value, fallback, maxLength) {
  if (value === undefined || value === null) return fallback
  var text = String(value).replace(/[<>&\x00-\x1f\x7f]/g, "").slice(0, maxLength)
  return text !== "" ? text : fallback
}

function clampInt(value, fallback, min, max) {
  var n = Number(value)
  if (!isFinite(n)) return fallback
  n = Math.round(n)
  return Math.max(min, Math.min(max, n))
}

function parseStatus(raw) {
  var s = defaultStatus()
  if (typeof raw !== "string" || raw === "" || raw.length > 16384) {
    s.ok = false
    s.error = "No answer from the keyboard helper"
    return s
  }
  var data
  try { data = JSON.parse(raw) }
  catch (e) { s.ok = false; s.error = "Unreadable answer from the keyboard helper"; return s }
  if (!data || typeof data !== "object") { s.ok = false; s.error = "Unreadable answer from the keyboard helper"; return s }

  s.connected = data.connected === true
  var access = String(data.access || "absent")
  s.access = (access === "ok" || access === "denied" || access === "unsupported") ? access : "absent"
  s.device = cleanText(data.device, "", 64)
  s.model = cleanText(data.model, "", 64)
  s.firmware = cleanText(data.firmware, "", 32)
  s.serial = cleanText(data.serial, "", 48)
  s.profileCount = clampInt(data.profileCount, 4, 1, 16)
  s.profileIndex = clampInt(data.profileIndex, -1, -1, s.profileCount - 1)
  s.error = cleanText(data.error, "", 200)
  return s
}

function settingBool(settings, key, fallback) {
  var v = settings ? settings[key] : undefined
  if (v === undefined || v === null) return fallback
  return v === true || v === "true"
}

function settingNumber(settings, key, fallback, min, max) {
  var v = settings ? settings[key] : undefined
  if (v === undefined || v === null || v === "") return fallback
  return clampInt(v, fallback, min, max)
}

function profileName(settings, index) {
  var v = settings ? settings["profile" + (index + 1) + "Name"] : ""
  return cleanText(v, "", 24)
}

function profileLabel(settings, index) {
  var name = profileName(settings, index)
  return name !== "" ? name : "Profile " + (index + 1)
}

function profileOptions(settings, count) {
  var options = []
  for (var i = 0; i < count; i++) {
    options.push({ value: String(i), label: profileLabel(settings, i) })
  }
  return options
}

// Short label for the bar: a custom name if there is one, else P1..P4.
function barProfileText(settings, index) {
  if (index < 0) return ""
  var name = profileName(settings, index)
  return name !== "" ? name.slice(0, 12) : "P" + (index + 1)
}

function barText(keys, settings, showLabel) {
  if (!keys || !keys.connected || !showLabel) return KEYBOARD_GLYPH
  var label = barProfileText(settings, keys.profileIndex)
  return label !== "" ? KEYBOARD_GLYPH + " " + label : KEYBOARD_GLYPH
}

function accessHint(access) {
  if (access === "denied") return "Your session is not allowed to open the keyboard yet."
  if (access === "unsupported") return "This keyboard uses a newer protocol Hall Keys does not speak yet."
  return "Plug in a Wooting keyboard over USB."
}

function barTooltip(keys, settings) {
  if (!keys) return "Hall Keys"
  if (!keys.connected) return "Hall Keys: " + accessHint(keys.access)
  var parts = [keys.model || "Wooting keyboard"]
  if (keys.profileIndex >= 0) parts.push(profileLabel(settings, keys.profileIndex))
  return parts.join(" · ")
}

function isHexColor(text) {
  return typeof text === "string" && /^#[0-9a-fA-F]{6}$/.test(text)
}

// keyboard.rgb holds one color, with or without a leading '#'. QML color
// strings may carry an alpha channel ("#aarrggbb"); drop it.
function normalizeColor(text, fallback) {
  var t = String(text || "").trim().replace(/^#/, "")
  if (/^[0-9a-fA-F]{6}$/.test(t)) return "#" + t.toLowerCase()
  var f = String(fallback || "").trim().replace(/^#/, "")
  if (f.length === 8) f = f.slice(2)
  if (/^[0-9a-fA-F]{6}$/.test(f)) return "#" + f.toLowerCase()
  return ""
}

function pathFromUrl(url) {
  var s = String(url)
  return s.indexOf("file://") === 0 ? decodeURIComponent(s.slice(7)) : s
}

// Fixed command surface: write the rule text above, reload udev, retrigger hidraw.
function grantAccessCommand() {
  var rule = UDEV_RULE_LINES.join("\n")
  var script = "printf '%s\\n' '" + rule + "' > " + UDEV_RULE_PATH
    + " && udevadm control --reload && udevadm trigger --subsystem-match=hidraw --subsystem-match=usb"
  return ["pkexec", "sh", "-c", script]
}
