// Top bar: a half-sunk Borjgali sun in the centre with music rays along the strip, date · part of the
// day · time on its left, song on its right; cross-stitch diamond workspaces left, status icons right.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
  id: root
  required property var modelData
  screen: modelData
  WlrLayershell.namespace: "pharnavos-bar"
  WlrLayershell.layer: Quickshell.env("PHARNAVOS_PREVIEW") ? WlrLayer.Overlay : WlrLayer.Top
  anchors { top: true; left: true; right: true }
  implicitHeight: 480   // room for the popups under the strip (only the strip and an open popup take input)
  exclusiveZone: 46
  color: "transparent"
  mask: Region { item: barBg; Region { item: pops } }

  // small screens: the status pill and workspaces sit tighter, to leave the song some room
  readonly property bool tight: width < 1800
  readonly property color red: Theme.red
  readonly property color cream: Theme.cream
  readonly property color dim: Theme.dim
  readonly property string mono: "FiraCode Nerd Font"

  // ---- data -------------------------------------------------------------
  property var now: new Date()
  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

  readonly property MprisPlayer player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
  readonly property bool playing: player?.isPlaying ?? false
  property var bands: Array(19).fill(0)
  Process {
    id: cava
    running: root.playing
    command: ["cava", "-p", Quickshell.shellDir + "/cava.conf"]
    stdout: SplitParser { onRead: line => root.bands = line.split(";").slice(0, 19).map(Number) }
    onRunningChanged: if (!running) root.bands = Array(19).fill(0)
  }
  // cava can die (e.g. PipeWire restarts) while music keeps playing: re-arm it
  Timer { interval: 3000; running: root.playing && !cava.running; onTriggered: cava.running = Qt.binding(() => root.playing) }

  readonly property PwNode sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: [root.sink] }

  // the active keyboard layout as a short tag: us → EN, ge → KA, de → DE…
  property string layout: "EN"
  Process {
    id: kb
    running: true
    command: ["hyprctl", "devices", "-j"]
    stdout: StdioCollector { onStreamFinished: {
      const k = JSON.parse(text).keyboards.find(k => k.main); if (!k) return;
      const c = (k.layout.split(",")[k.active_layout_index] || "us").trim();
      root.layout = ({ us: "EN", gb: "EN", ge: "KA" })[c] || c.slice(0, 2).toUpperCase();
    } }
  }
  Connections {
    target: Hyprland
    function onRawEvent(e) { if (e.name === "activelayout") kb.running = true }
  }

  ControlCenter { bar: root }
  Notifications { bar: root }
  Launcher { bar: root }
  Osd { bar: root }
  IdleInhibitor { window: root; enabled: Rice.cfg.awake }

  Popups { id: pops; bar: root; z: 5 }

  // ---- bar strip ---------------------------------------------------------
  Rectangle {
    id: barBg
    width: parent.width; height: 46
    color: "#070607"
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.alpha(Theme.red, 0.18) }

    // ---- horizon: the sun rises half-sunk out of the strip's lower edge, music rays fan out along it
    Item {
      id: hz
      anchors.fill: parent; clip: true
      readonly property real cx: width / 2
      readonly property string word: Rice.cfg.clockFmt === "ka" ? Theme.period(root.now, "ka") : ""

      Row {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        spacing: 5
        Repeater {
          model: 37
          Rectangle {
            required property int index
            readonly property int d: Math.abs(index - 18)
            readonly property real h: d < 6 ? 0 : Math.max(3, Math.min(42, 3 + root.bands[Math.min(18, d)] * 0.8 * (1 - d / 30)))
            anchors.bottom: parent.bottom
            width: 3; height: h; radius: 1.5
            color: h > 30 ? root.cream : root.red
            opacity: 1 - d / 30
            Behavior on height { NumberAnimation { duration: 70 } }
          }
        }
      }

      // left wing, hugging the sun (as the song does on the right). One line when it fits:
      // date · part of the day · time; else two lines: the time, and under it part of the day · date
      readonly property real wing: 160
      readonly property real room: hz.cx - wing - wsRow.x - wsRow.width - 24
      readonly property string dateText: Theme.days[root.now.getDay()] + " " + root.now.getDate() + " " + Theme.monthsShort[root.now.getMonth()]
      readonly property string timeText: Theme.time(root.now, Rice.cfg.clockFmt)
      readonly property string ampm: Rice.cfg.clockFmt === "ampm" ? Theme.period(root.now, "ampm") : ""   // after the time, rosé
      readonly property bool oneLine: oneRow.implicitWidth <= room
      Row {
        id: oneRow
        visible: hz.oneLine
        anchors { right: parent.right; rightMargin: parent.width - hz.cx + hz.wing; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
        spacing: 9
        Text { id: hzTimeT; visible: false; text: hz.timeText; font { family: Theme.labelFor(text); pixelSize: 23 } }   // baseline only
        Text { anchors.baseline: hzTimeT.baseline; text: hz.dateText; color: Theme.c("#C9C1C4"); font { family: Theme.labelFor(text); pixelSize: 23 } }
        Text { anchors.baseline: hzTimeT.baseline; text: "·"; color: Theme.c("#3A2E33"); font { family: Theme.sans; pixelSize: 15; bold: true } }
        Text { visible: hz.word !== ""; anchors.baseline: hzTimeT.baseline; text: hz.word; color: Theme.rose; font { family: Theme.labelFor(text); pixelSize: 23 } }
        // same font as the date (BPG has no bold, so white instead of bold makes the time lead)
        Text { anchors.baseline: hzTimeT.baseline; text: hz.timeText; color: "#FFFFFF"; font { family: Theme.labelFor(text); pixelSize: 23 } }
        Text { visible: hz.ampm !== ""; anchors.baseline: hzTimeT.baseline; text: hz.ampm; color: Theme.rose; font { family: Theme.labelFor(text); pixelSize: 23 } }
      }
      Column {
        // two lines: the part of the day (rosé) before the time, the date underneath
        visible: !hz.oneLine
        anchors { right: parent.right; rightMargin: parent.width - hz.cx + hz.wing; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
        spacing: 1
        Row {
          anchors.right: parent.right; spacing: 6
          Text { id: line1T; text: hz.timeText; visible: false; font { family: Theme.labelFor(text); pixelSize: 20 } }   // baseline only
          Text { visible: hz.word !== ""; anchors.baseline: line1T.baseline; text: hz.word; color: Theme.rose; font { family: Theme.labelFor(text); pixelSize: 13 } }
          Text { anchors.baseline: line1T.baseline; text: hz.timeText; color: "#FFFFFF"; font { family: Theme.labelFor(text); pixelSize: 20 } }
          Text { visible: hz.ampm !== ""; anchors.baseline: line1T.baseline; text: hz.ampm; color: Theme.rose; font { family: Theme.labelFor(text); pixelSize: 13 } }
        }
        Text { anchors.right: parent.right; text: hz.dateText; color: Theme.c("#C9C1C4"); font { family: Theme.labelFor(text); pixelSize: 12 } }
      }

      // the half-sunk sun: black gap ring, red rim, spinning collage Borjgali
      Rectangle { x: hz.cx - 44; y: 0; width: 88; height: 88; radius: 44; color: "#070607"; border { width: 1; color: Theme.alpha(Theme.red, 0.35) } }
      Rectangle {
        x: hz.cx - 38; y: 6; width: 76; height: 76; radius: 38
        color: Theme.c("#0E0B0D"); border { width: 1.5; color: root.red }
        Image {
          anchors.centerIn: parent; width: 60; height: 60
          source: "file://" + Quickshell.shellDir + "/assets/cutouts/borjgali-collage.png"
          sourceSize: Qt.size(120, 120); mipmap: true
          id: arms
          scale: root.playing ? 1 + Math.min(root.bands[0] * 1.5, 120) / 900 : 1
          Behavior on scale { NumberAnimation { duration: 80 } }
        }
        MouseArea { anchors.fill: parent; onClicked: root.player?.togglePlaying() }
        // stepped at 30 Hz: on a 300 Hz monitor a smooth animation would redraw the bar 300×/s
        Timer {
          interval: 33; running: true; repeat: true
          onTriggered: arms.rotation = (arms.rotation + 0.033 * 360 / (root.playing ? 8 : 40)) % 360
        }
      }

      // the song, in a pill like the status ones: a note, then the title scrolling in its own clipped slot
      // (the note never scrolls). Too little room for a title (screens under ~1300 px): the note and a
      // small equaliser moving with the music, the title on hover
      MouseArea {
        id: songBox
        hoverEnabled: true
        onContainsMouseChanged: root.tipFor(this, containsMouse && !slot.visible)
        readonly property real room: statusRow.x - 10 - x
        readonly property string title: [root.player?.trackArtist, root.player?.trackTitle].filter(s => s).join(" — ")
        visible: root.playing && room >= 56
        x: hz.cx + 148; anchors.verticalCenter: parent.verticalCenter
        width: Math.min(room, slot.visible ? 42 + songM.advanceWidth + 4 : 64, 380); height: 38
        Rectangle { anchors.fill: parent; radius: 19; color: Theme.c("#0E0B0D"); border.color: Theme.c("#3A2E33") }
        Shape {
          x: 12; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 16; preferredRendererType: Shape.CurveRenderer
          ShapePath { fillColor: root.red; strokeWidth: 0; strokeColor: "transparent"; PathSvg { path: "M5 2 L14 0 L14 11 A2.6 2.6 0 1 1 12 8.6 L12 3 L7 4 L7 13 A2.6 2.6 0 1 1 5 10.6 Z" } }
        }
        // equaliser: four bars from cava's bands
        Row {
          visible: !slot.visible
          x: 32; anchors.verticalCenter: parent.verticalCenter; spacing: 2; height: 14
          Repeater {
            model: [1, 4, 8, 13]
            Rectangle {
              required property int modelData
              anchors.bottom: parent.bottom
              width: 3; radius: 1; color: root.red
              height: Math.max(3, Math.min(14, (root.bands[modelData] ?? 0) * 0.16))
            }
          }
        }
        Item {
          id: slot
          visible: songBox.room >= 96
          x: 34; width: parent.width - 34 - 12; height: parent.height; clip: true
          readonly property bool long: songM.advanceWidth > width
          property real shift: 0
          onLongChanged: shift = 0
          // stepped at 30 Hz like the sun: a smooth animation would redraw the bar at the monitor's rate
          Timer {
            interval: 33; repeat: true; running: songBox.visible && slot.visible && slot.long
            onTriggered: slot.shift = (slot.shift + 1) % (songM.advanceWidth + 48)
          }
          Row {
            x: -slot.shift; anchors.verticalCenter: parent.verticalCenter; spacing: 48
            Repeater {
              model: slot.long ? 2 : 1
              Text {
                // names from players, apps and nearby Wi-Fi are shown as plain text: as rich text, a title like
                // <img src="https://…"> would load from the internet
                textFormat: Text.PlainText
                text: songBox.title
                color: root.cream; font { family: Theme.headFor(text); pixelSize: 16 }
              }
            }
          }
          TextMetrics { id: songM; font { family: Theme.headFor(songBox.title); pixelSize: 16 } text: songBox.title }
          // the title fades in and out at the slot's ends while it scrolls
          Rectangle {
            visible: slot.long; width: 10; height: parent.height
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.c("#0E0B0D") } GradientStop { position: 1; color: Theme.c("#000E0B0D") } }
          }
          Rectangle {
            visible: slot.long; anchors.right: parent.right; width: 14; height: parent.height
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.c("#000E0B0D") } GradientStop { position: 1; color: Theme.c("#0E0B0D") } }
          }
        }
      }
    }

    // workspaces: Khevsur cross-stitch diamonds
    Row {
      id: wsRow
      // narrow screens: the diamonds sit closer so the clock has room
      readonly property bool tight: root.tight
      x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: tight ? 2 : 8
      Repeater {
        model: 9
        MouseArea {
          id: ws
          required property int index
          readonly property bool on: Hyprland.focusedWorkspace?.id === index + 1
          readonly property bool used: Hyprland.workspaces.values.some(w => w.id === index + 1 && w.toplevels.values.length > 0)
          width: wsRow.tight ? 30 : 32; height: 32
          onClicked: Rice.dispatch("workspace " + (index + 1), "hl.dsp.focus({ workspace = " + (index + 1) + " })")
          Diamond {
            anchors.centerIn: parent
            size: ws.on ? 25 : 20
            fill: ws.on ? root.red : ws.used ? root.cream : Theme.c("#2E272A")
            core: ws.on ? "#FFFFFF" : ws.used ? root.cream : Theme.c("#2E272A")
            glow: ws.on
          }
        }
      }
    }

    Row {
      id: statusRow
      anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
      spacing: 2

      Repeater {
        model: SystemTray.items
        IconBtn {
          id: tray
          required property SystemTrayItem modelData
          IconImage { anchors.centerIn: parent; implicitSize: 16; source: tray.modelData.icon }
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: m => {
            if (m.button === Qt.LeftButton && !modelData.onlyMenu) modelData.activate();
            else if (modelData.hasMenu) modelData.display(root, mapToItem(null, 0, 0).x, 46);
          }
        }
      }
      Item { width: root.tight ? 2 : 8; height: 1 }
      // two pills as tall as the jars: what you click, then what you read (battery, CPU, memory)
      Pill {
        pad: root.tight ? 5 : 8
      MouseArea {
        width: root.tight ? 40 : 44; height: 34
        onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])   // a hyprctl command, not a dispatcher: same in both config types
        Rectangle {
          anchors.centerIn: parent; width: 40; height: 26; radius: 13
          color: "transparent"; border.color: root.red
          Text { anchors.centerIn: parent; text: root.layout; color: root.red; font { family: root.mono; pixelSize: 12; bold: true } }
        }
      }
      // Wi-Fi: arcs light with the signal (wired = full), red and crossed out when offline;
      // hover = traffic, click = NetworkManager's own settings window
      IconBtn {
        id: netBtn
        readonly property int arcs: !Sys.online ? 0 : Sys.ssid === "" ? 3 : Sys.signal > 66 ? 3 : Sys.signal > 33 ? 2 : 1
        onClicked: Quickshell.execDetached(["nm-connection-editor"])
        onContainsMouseChanged: pops.hover("wifi", this, containsMouse)
        Repeater {
          model: ["M2 8.5a15 15 0 0 1 20 0", "M5 12a10 10 0 0 1 14 0", "M8.5 15.5a5 5 0 0 1 7 0", "M12 19h.01"]
          Icon {
            required property int index
            required property string modelData
            d: modelData
            c: !Sys.online ? root.red : (index === 3 || index >= 3 - netBtn.arcs) ? netBtn.fg : Theme.c("#2E272A")
          }
        }
        Icon { visible: !Sys.online; d: "M4 4l16 16"; c: root.red }
      }
      // Bluetooth: dim off, cream on, red dot with a device connected; hover = devices + battery,
      // click = turn it on (if off) and open blueman's manager
      IconBtn {
        id: btBtn
        readonly property var devs: Bluetooth.devices.values.filter(d => d.connected)
        on: Bluetooth.defaultAdapter?.enabled ?? false
        onClicked: {
          if (Bluetooth.defaultAdapter && !on) Bluetooth.defaultAdapter.enabled = true;
          Quickshell.execDetached(["blueman-manager"])
        }
        onContainsMouseChanged: pops.hover("bt", this, containsMouse)
        Icon { d: "M7 7l10 10-5 4V3l5 4L7 17"; c: parent.fg }
        Rectangle { visible: btBtn.devs.length > 0; x: 22; y: 6; width: 7; height: 7; radius: 3.5; color: root.red }
      }
      IconBtn {
        width: root.tight ? 56 : 64
        onContainsMouseChanged: pops.hover("sound", this, containsMouse)
        on: !(root.sink?.audio.muted ?? true)
        onClicked: if (root.sink) root.sink.audio.muted = !root.sink.audio.muted
        onWheel: w => { if (root.sink) root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))) }
        Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; anchors.centerIn: undefined; d: "M4 9v6h4l5 4V5L8 9zM16 9a4 4 0 0 1 0 6M19 6a8 8 0 0 1 0 12"; c: parent.fg }
        Level { anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: optical; text: Math.round((root.sink?.audio.volume ?? 0) * 100); color: parent.fg }
      }
      // brightness, on screens with a backlight (laptops): scroll ±5%, click 30% ↔ 100%, hover = slider
      IconBtn {
        visible: Sys.backlight !== ""
        width: root.tight ? 56 : 64
        on: true
        onContainsMouseChanged: pops.hover("bri", this, containsMouse)
        onClicked: Sys.setBright(Sys.bright < 0.99 ? 1 : 0.3)
        onWheel: w => Sys.setBright(Sys.bright + (w.angleDelta.y > 0 ? 0.05 : -0.05))
        Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; anchors.centerIn: undefined; d: "M12 8a4 4 0 1 0 0.01 0M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"; c: parent.fg }
        Level { anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: optical; text: Math.round(Sys.bright * 100); color: parent.fg }
      }
      // power profile: the needle shows the mode (left saver, up balanced, right performance, red);
      // click = next profile, named in the tooltip for a moment
      IconBtn {
        id: ppBtn
        visible: Rice.power && Sys.powerAvailable   // programs.pharnavos.powerProfiles, and a daemon to talk to
        onClicked: Sys.cycleProfile()
        onContainsMouseChanged: pops.hover("power", this, containsMouse)
        Icon {
          d: "M4 18a8 8 0 1 1 16 0" + (Sys.profile === "performance" ? "M12 18l5-3" : Sys.profile === "power-saver" ? "M12 18l-5-3" : "M12 18l0-7")
          c: Sys.profile === "performance" ? "#FF3B3B" : parent.fg   // performance is red in every colour theme
        }
      }
      IconBtn {
        on: Rice.notifCount > 0
        onClicked: { Rice.panelScreen = root.screen.name; Rice.notifShowAll = !Rice.notifShowAll }
        Icon { d: "M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 21h4"; c: parent.fg }
        // open: a red ring (outline kept, never a solid fill)
        Rectangle { anchors.fill: parent; radius: 17; color: "transparent"; border { width: 1.5; color: root.red } visible: Rice.notifShowAll }
        Rectangle { visible: Rice.notifCount > 0 && !Rice.notifShowAll; x: 21; y: 6; width: 8; height: 8; radius: 4; color: root.red }
      }
      }
      Item { width: 6; height: 1 }
      Pill {
        id: jarPill
        glow: true; spacing: 9; pad: 13
      // battery (laptops only): one more qvevri, its wine the charge with the percentage written on it;
      // hot red and throbbing when low, a slow breath while charging; hover says what it is
      MouseArea {
        id: batHit
        readonly property var dev: UPower.displayDevice
        readonly property real pct: Math.round(dev ? (dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 0)
        readonly property bool charging: dev?.state === UPowerDeviceState.Charging || dev?.state === UPowerDeviceState.PendingCharge
        visible: !!dev && dev.ready && dev.isLaptopBattery && dev.isPresent
        width: visible ? 19 : 0; height: 34; hoverEnabled: true
        onContainsMouseChanged: pops.hover("jars", jarPill, containsMouse)
        Qvevri {
          anchors.centerIn: parent; scale: 1.05; glow: true
          // rosé, like a Tavkveri or Shavkapito: apart from the CPU's red and the memory's white
          level: batHit.pct; glyph: root.jarLetter[Rice.t("ბ", "B")]; wine: Theme.pink   // ბატარეა; the numbers are on hover
          alarm: batHit.pct <= 15 && !batHit.charging
          pulse: alarm
          SequentialAnimation on opacity { running: batHit.charging; loops: Animation.Infinite; NumberAnimation { to: 0.7; duration: 900 } NumberAnimation { to: 1; duration: 900 } }
        }
      }
      // load as two qvevri: wine rises with CPU (red) and RAM (cream); hover for numbers
      MouseArea {
        id: loadHit
        width: loadRow.width; height: 34; hoverEnabled: true
        onContainsMouseChanged: pops.hover("jars", jarPill, containsMouse)
        Row {
          id: loadRow
          anchors.centerIn: parent; spacing: 10
          Repeater {
            // პროცესორი and მეხსიერება, by their first letters; the numbers are on hover
            model: [[root.jarLetter[Rice.t("პ", "C")], Sys.cpu, Theme.c("#B0151F")], [root.jarLetter[Rice.t("მ", "M")], Sys.ram, Theme.c("#C9C1C4")]]
            Item {
              required property var modelData
              width: 17; height: 26
              Qvevri { anchors.centerIn: parent; level: parent.modelData[1]; wine: parent.modelData[2]; glyph: parent.modelData[0]; scale: 1.05; glow: true }
            }
          }
        }
      }
      }
      // an app being installed / removed / the system updating: a turning ring and its name
      Item {
        visible: Apps.busy
        width: jobRow.width + 16; height: 34
        Rectangle { anchors.fill: parent; radius: 17; color: "transparent"; border.color: "#5FBF77"; opacity: 0.6 }
        Row {
          id: jobRow
          anchors.centerIn: parent; spacing: 8
          Rectangle {
            width: 14; height: 14; radius: 7; color: "transparent"; border { width: 2; color: "#5FBF77" }
            anchors.verticalCenter: parent.verticalCenter
            Rectangle { width: 4; height: 4; radius: 2; color: Theme.c("#0E0B0D"); x: 5; y: -1 }
            RotationAnimation on rotation { from: 0; to: 360; duration: 1100; loops: Animation.Infinite; running: Apps.busy }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Apps.target || ({ update: Rice.t("განახლება", "updating"), undo: Rice.t("გაუქმება", "undoing") })[Apps.job] || ""
            color: "#5FBF77"; font { family: root.mono; pixelSize: 12; bold: true }
          }
        }
      }
      Item { width: 4; height: 1 }
      IconBtn {
        // the Bolnisi cross in its circle: arms thin at the centre, flaring like trumpets — opens the control centre
        // as tall as the pills beside it: drawn on a 24 grid, scaled to 38
        width: 38; height: 38
        onClicked: { Rice.panelScreen = root.screen.name; Rice.ccOpen = !Rice.ccOpen }
        Shape {
          anchors.centerIn: parent; width: 24; height: 24; scale: 38 / 24
          preferredRendererType: Shape.CurveRenderer
          ShapePath { strokeColor: root.red; strokeWidth: 1; fillColor: "transparent"; PathSvg { path: "M12 0.5 A11.5 11.5 0 1 1 11.99 0.5" } }
          ShapePath { strokeWidth: 0; strokeColor: "transparent"; fillColor: root.red; PathSvg { path: "M11.24 12 Q11.41 6.96 8.14 3.94 Q12 5.78 15.86 3.94 Q12.59 6.96 12.76 12ZM12 11.24 Q17.04 11.41 20.06 8.14 Q18.22 12 20.06 15.86 Q17.04 12.59 12 12.76ZM12.76 12 Q12.59 17.04 15.86 20.06 Q12 18.22 8.14 20.06 Q11.41 17.04 11.24 12ZM12 12.76 Q6.96 12.59 3.94 15.86 Q5.78 12 3.94 8.14 Q6.96 11.41 12 11.24Z" } }
          ShapePath { strokeWidth: 0; strokeColor: "transparent"; fillColor: root.red; PathSvg { path: "M10.9 12 A1.1 1.1 0 1 1 13.1 12 A1.1 1.1 0 1 1 10.9 12Z" } }
        }
      }
    }
  }

  // one tooltip under whichever status item is hovered (or just clicked, for the power profile)
  property Item tipItem: null
  function tipFor(item, on) { if (on) root.tipItem = item; else if (root.tipItem === item) root.tipItem = null }
  // the one tooltip left: the song's title when there's no room to show it (the icons have popups)
  readonly property string tipText: root.tipItem === songBox ? songBox.title : ""

  Rectangle {
    visible: root.tipItem !== null && root.tipText !== ""
    // centred under the item, but kept on screen (they sit near the right edge)
    x: root.tipItem ? Math.min(root.width - width - 12, root.tipItem.mapToItem(root.contentItem, 0, 0).x + root.tipItem.width / 2 - width / 2) : 0; y: 52
    width: tipT.implicitWidth + 28; height: tipT.implicitHeight + 18; radius: 10
    color: Theme.c("#0E0B0D"); border.color: Theme.c("#3A2E33")
    Text {
      id: tipT; anchors.centerIn: parent
      text: root.tipText; lineHeight: 1.3; horizontalAlignment: Text.AlignHCenter
      color: root.cream; font { family: root.mono; pixelSize: 12; bold: true }
    }
  }


  // ---- little components ---------------------------------------------------
  // the jars' letters, outlines from BPG Excelsior Caps fitted to the jar's 16×24 box:
  // ბ for ბატარეა, პ for პროცესორი, მ for მეხსიერება (English: B, C, M)
  readonly property var jarLetter: ({
    "ბ": "M8.01 15.5Q7.2 15.5 6.56 15.13Q5.93 14.76 5.6 14.07Q5.27 13.38 5.27 12.4Q5.27 11.47 5.57 10.8Q5.87 10.12 6.39 9.79Q6.92 9.47 7.64 9.4L7.79 8.46Q7.87 7.88 7.32 7.62Q6.77 7.36 6.77 6.5H7.83Q7.82 6.9 8.3 7.19Q8.77 7.49 8.71 8.34L8.51 9.42Q9.14 9.5 9.63 9.81Q10.13 10.12 10.43 10.8Q10.73 11.47 10.73 12.4Q10.73 13.38 10.4 14.07Q10.07 14.76 9.44 15.13Q8.8 15.5 8.01 15.5ZM8 14.65Q8.71 14.65 9.2 14.14Q9.69 13.62 9.69 12.42Q9.69 11.26 9.21 10.75Q8.73 10.23 8.11 10.23Q7.27 10.23 6.79 10.75Q6.31 11.26 6.31 12.42Q6.31 13.62 6.8 14.14Q7.29 14.65 8 14.65Z",
    "პ": "M7.52 6.5Q7.52 6.89 9.04 7.06Q10.56 7.23 10.56 8.67Q10.57 9.51 9.61 10.05Q10.18 10.4 10.46 10.97Q10.73 11.55 10.73 12.07Q10.73 13.38 10.4 14.07Q10.07 14.76 9.44 15.13Q8.8 15.5 8.01 15.5Q7.2 15.5 6.56 15.13Q5.93 14.76 5.6 14.07Q5.27 13.38 5.27 12.36Q5.27 11.8 5.54 11L6.54 11.25Q6.31 11.87 6.31 12.38Q6.31 13.62 6.8 14.14Q7.29 14.65 8 14.65Q8.71 14.65 9.2 14.14Q9.69 13.62 9.69 12.09Q9.69 11.4 9.24 10.9Q8.79 10.4 8.11 10.4H7.49V9.55H8.47Q9.02 9.55 9.27 9.4Q9.52 9.25 9.52 8.64Q9.52 7.77 7.89 7.63Q6.26 7.5 6.26 6.5Z",
    "მ": "M10.73 12.4Q10.73 13.38 10.4 14.07Q10.07 14.76 9.44 15.13Q8.8 15.5 8.01 15.5Q7.2 15.5 6.56 15.13Q5.93 14.76 5.6 14.07Q5.27 13.38 5.27 12.4Q5.27 11.47 5.57 10.8Q5.87 10.12 6.46 9.75Q7.05 9.38 8.01 9.38Q8.95 9.38 9.75 10.23V8.56Q9.75 8.01 9.29 7.66Q8.84 7.3 8.15 7.3Q7.42 7.3 7.01 7.57Q6.61 7.84 6.61 8.39H5.58Q5.58 7.55 6.27 7.02Q6.97 6.5 8.16 6.5Q9.26 6.5 10 7.11Q10.73 7.71 10.73 8.59ZM8 14.65Q8.71 14.65 9.23 14.14Q9.75 13.62 9.75 12.42Q9.75 11.27 9.24 10.75Q8.73 10.23 8 10.23Q7.27 10.23 6.79 10.75Q6.31 11.27 6.31 12.42Q6.31 13.62 6.8 14.14Q7.29 14.65 8 14.65Z",
    "B": "M6.03 11.2V14.5H7.98Q8.96 14.5 9.43 14.09Q9.91 13.69 9.91 12.85Q9.91 12 9.43 11.6Q8.96 11.2 7.98 11.2ZM6.03 7.5V10.21H7.83Q8.72 10.21 9.16 9.88Q9.59 9.54 9.59 8.86Q9.59 8.18 9.16 7.84Q8.72 7.5 7.83 7.5ZM4.81 6.5H7.92Q9.31 6.5 10.06 7.08Q10.82 7.66 10.82 8.72Q10.82 9.55 10.43 10.04Q10.05 10.53 9.3 10.65Q10.2 10.84 10.69 11.45Q11.19 12.06 11.19 12.98Q11.19 14.19 10.37 14.84Q9.55 15.5 8.04 15.5H4.81Z",
    "C": "M11.5 7.33V8.56Q10.91 8.01 10.23 7.74Q9.56 7.46 8.81 7.46Q7.32 7.46 6.53 8.37Q5.74 9.28 5.74 11Q5.74 12.72 6.53 13.63Q7.32 14.54 8.81 14.54Q9.56 14.54 10.23 14.26Q10.91 13.99 11.5 13.44V14.66Q10.88 15.08 10.19 15.29Q9.5 15.5 8.74 15.5Q6.77 15.5 5.64 14.29Q4.5 13.09 4.5 11Q4.5 8.91 5.64 7.71Q6.77 6.5 8.74 6.5Q9.52 6.5 10.2 6.71Q10.89 6.91 11.5 7.33Z",
    "M": "M3.88 6.5H5.7L7.99 12.62L10.3 6.5H12.12V15.5H10.93V7.6L8.61 13.77H7.39L5.06 7.6V15.5H3.88Z"
  })

  component Pill: Rectangle {
    default property alias content: pillRow.data
    property bool glow: false
    property alias spacing: pillRow.spacing
    property real pad: 8              // inner margin at each end
    anchors.verticalCenter: parent.verticalCenter
    width: pillRow.implicitWidth + 2 * pad; height: 38; radius: 19
    color: Theme.c("#0E0B0D"); border { width: 1; color: glow ? Theme.alpha(Theme.c("#FF2A3A"), 0.55) : Theme.c("#3A2E33") }
    // the glow: a blurred copy of the outline behind the pill
    Rectangle {
      visible: parent.glow; z: -1
      anchors.fill: parent; radius: parent.radius; color: "transparent"; border { width: 2; color: Theme.alpha(Theme.c("#FF2A3A"), 0.7) }
      layer.enabled: visible
      layer.effect: MultiEffect { blurEnabled: true; blur: 0.7; blurMax: 12 }
    }
    Row { id: pillRow; anchors.centerIn: parent; spacing: 0 }
  }

  component IconBtn: MouseArea {
    property bool on: true
    readonly property color fg: containsMouse ? "#FFFFFF" : on ? Theme.c("#C9C1C4") : Theme.c("#5A4E53")
    width: 34; height: 34; hoverEnabled: true
    Rectangle { anchors.fill: parent; radius: height / 2; color: parent.containsMouse ? Theme.c("#1A1517") : "transparent" }
  }

  // the number beside the sound / brightness icon: its digits (not its line box) centred on the icon
  component Level: Text {
    id: lv
    x: 32
    // how far the digits' own middle sits from the line box's middle
    readonly property real optical: height / 2 - (lvFm.ascent + lvTm.tightBoundingRect.y + lvTm.tightBoundingRect.height / 2)
    font { family: root.mono; pixelSize: 12; bold: true }
    FontMetrics { id: lvFm; font: lv.font }
    TextMetrics { id: lvTm; font: lv.font; text: "0" }
  }

  component Icon: Shape {
    property string d
    property color c
    anchors.centerIn: parent; width: 18; height: 18
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: c; strokeWidth: 2; fillColor: "transparent"
      capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
      scale: Qt.size(0.75, 0.75)
      PathSvg { path: d }
    }
  }

  component Diamond: Item {
    property real size
    property color fill
    property color core
    property bool glow
    width: size; height: size
    Behavior on size { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
    layer.enabled: glow
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.red; shadowBlur: 0.5; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
    Repeater {
      model: [1, 3, 5, 3, 1]
      Rectangle {
        required property int index
        required property int modelData
        readonly property real u: parent.size / 5
        x: (5 - modelData) / 2 * u; y: index * u; width: modelData * u; height: u
        color: parent.fill
      }
    }
    Rectangle { x: parent.size * 0.4; y: parent.size * 0.4; width: parent.size / 5; height: parent.size / 5; color: parent.core }
  }

  // text laid on the lower arc of the ring (r = 68), centred at fraction `at` from the left end
}
