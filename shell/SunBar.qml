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
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
  id: root
  required property var modelData
  screen: modelData
  WlrLayershell.namespace: "pharnavos-bar"
  WlrLayershell.layer: Quickshell.env("PHARNAVOS_PREVIEW") ? WlrLayer.Overlay : WlrLayer.Top
  anchors { top: true; left: true; right: true }
  implicitHeight: 360
  exclusiveZone: 46
  color: "transparent"
  mask: Region { item: barBg }

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

  property bool georgian: false
  Process {
    running: true
    command: ["hyprctl", "devices", "-j"]
    stdout: StdioCollector { onStreamFinished: { const k = JSON.parse(text).keyboards.find(k => k.main); if (k) root.georgian = /georgian/i.test(k.active_keymap) } }
  }
  Connections {
    target: Hyprland
    function onRawEvent(e) { if (e.name === "activelayout") root.georgian = /georgian/i.test(e.data) }
  }

  ControlCenter { bar: root }
  Notifications { bar: root }
  Launcher { bar: root }
  Osd { bar: root }
  IdleInhibitor { window: root; enabled: Rice.cfg.awake }

  // ---- bar strip ---------------------------------------------------------
  Rectangle {
    id: barBg
    width: parent.width; height: 46
    color: "#070607"
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 59 / 255, 59 / 255, 0.18) }

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

      // left wing, one line: date · part of the day · time (24h: date · time; AM/PM: date · time PM)
      Row {
        anchors { right: parent.right; rightMargin: parent.width - hz.cx + 172; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
        spacing: 9
        // on narrow screens the date would run into the workspaces (they end at ~370 px): drop it
        readonly property bool roomy: hz.cx - 172 - (hzDateT.implicitWidth + hzDotT.implicitWidth + hzWordT.implicitWidth + hzTimeT.implicitWidth + 36) > 380
        Text {
          id: hzDateT
          visible: parent.roomy
          anchors.baseline: hzTimeT.baseline
          text: Theme.days[root.now.getDay()] + " " + root.now.getDate() + " "
                + Theme.monthsShort[root.now.getMonth()]
          color: "#C9C1C4"; font { family: Theme.labelFor(text); pixelSize: 23 }
        }
        Text { id: hzDotT; visible: parent.roomy; anchors.baseline: hzTimeT.baseline; text: "·"; color: "#3A2E33"; font { family: Theme.sans; pixelSize: 15; bold: true } }
        Text {
          id: hzWordT
          visible: hz.word !== ""
          anchors.baseline: hzTimeT.baseline
          text: hz.word; color: "#FF5A66"; font { family: Theme.labelFor(text); pixelSize: 23 }
        }
        Text {
          id: hzTimeT
          text: Theme.time(root.now, Rice.cfg.clockFmt) + (Rice.cfg.clockFmt === "ampm" ? " " + Theme.period(root.now, "ampm") : "")
          // same font as the date (BPG has no bold, so white instead of bold makes the time lead)
          color: "#FFFFFF"; font { family: Theme.labelFor(text); pixelSize: 23 }
        }
      }

      // the half-sunk sun: black gap ring, red rim, spinning collage Borjgali
      Rectangle { x: hz.cx - 44; y: 0; width: 88; height: 88; radius: 44; color: "#070607"; border { width: 1; color: Qt.rgba(1, 59 / 255, 59 / 255, 0.35) } }
      Rectangle {
        x: hz.cx - 38; y: 6; width: 76; height: 76; radius: 38
        color: "#0E0B0D"; border { width: 1.5; color: root.red }
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

      Text {
        visible: root.playing
        x: hz.cx + 172; anchors.verticalCenter: parent.verticalCenter; width: 320; elide: Text.ElideRight
        // names from players, apps and nearby Wi-Fi are shown as plain text: as rich text, a title like
        // <img src="https://…"> would load from the internet
        textFormat: Text.PlainText
        text: [root.player?.trackArtist, root.player?.trackTitle].filter(s => s).join(" — ")
        color: root.cream; font { family: Theme.headFor(text); pixelSize: 16 }
      }
    }

    // workspaces: Khevsur cross-stitch diamonds
    Row {
      x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 8
      Repeater {
        model: 9
        MouseArea {
          id: ws
          required property int index
          readonly property bool on: Hyprland.focusedWorkspace?.id === index + 1
          readonly property bool used: Hyprland.workspaces.values.some(w => w.id === index + 1 && w.toplevels.values.length > 0)
          width: 32; height: 32
          onClicked: Rice.dispatch("workspace " + (index + 1), "hl.dsp.focus({ workspace = " + (index + 1) + " })")
          Diamond {
            anchors.centerIn: parent
            size: ws.on ? 25 : 20
            fill: ws.on ? root.red : ws.used ? root.cream : "#2E272A"
            core: ws.on ? "#FFFFFF" : ws.used ? root.cream : "#2E272A"
            glow: ws.on
          }
        }
      }
    }

    Row {
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
      Item { width: 8; height: 1 }
      MouseArea {
        width: 44; height: 34
        onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])   // a hyprctl command, not a dispatcher: same in both config types
        Rectangle {
          anchors.centerIn: parent; width: 40; height: 26; radius: 13
          color: "transparent"; border.color: root.red
          Text { anchors.centerIn: parent; text: root.georgian ? "KA" : "EN"; color: root.red; font { family: root.mono; pixelSize: 12; bold: true } }
        }
      }
      // Wi-Fi: arcs light with the signal (wired = full), red and crossed out when offline;
      // hover = traffic, click = NetworkManager's own settings window
      IconBtn {
        id: netBtn
        readonly property int arcs: !Sys.online ? 0 : Sys.ssid === "" ? 3 : Sys.signal > 66 ? 3 : Sys.signal > 33 ? 2 : 1
        onClicked: Quickshell.execDetached(["nm-connection-editor"])
        onContainsMouseChanged: root.tipFor(this, containsMouse)
        Repeater {
          model: ["M2 8.5a15 15 0 0 1 20 0", "M5 12a10 10 0 0 1 14 0", "M8.5 15.5a5 5 0 0 1 7 0", "M12 19h.01"]
          Icon {
            required property int index
            required property string modelData
            d: modelData
            c: !Sys.online ? root.red : (index === 3 || index >= 3 - netBtn.arcs) ? netBtn.fg : "#2E272A"
          }
        }
        Icon { visible: !Sys.online; d: "M4 4l16 16"; c: root.red }
      }
      // Bluetooth: dim off, cream on, red dot with a device connected; hover = devices + battery,
      // click = blueman's manager
      IconBtn {
        id: btBtn
        readonly property var devs: Bluetooth.devices.values.filter(d => d.connected)
        on: Bluetooth.defaultAdapter?.enabled ?? false
        onClicked: Quickshell.execDetached(["blueman-manager"])
        onContainsMouseChanged: root.tipFor(this, containsMouse)
        Icon { d: "M7 7l10 10-5 4V3l5 4L7 17"; c: parent.fg }
        Rectangle { visible: btBtn.devs.length > 0; x: 22; y: 6; width: 7; height: 7; radius: 3.5; color: root.red }
      }
      IconBtn {
        width: 64
        on: !(root.sink?.audio.muted ?? true)
        onClicked: if (root.sink) root.sink.audio.muted = !root.sink.audio.muted
        onWheel: w => { if (root.sink) root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))) }
        Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; anchors.centerIn: undefined; d: "M4 9v6h4l5 4V5L8 9zM16 9a4 4 0 0 1 0 6M19 6a8 8 0 0 1 0 12"; c: parent.fg }
        Text { x: 32; anchors.verticalCenter: parent.verticalCenter; text: Math.round((root.sink?.audio.volume ?? 0) * 100); color: parent.fg; font { family: root.mono; pixelSize: 12; bold: true } }
      }
      // power profile: the needle shows the mode (left saver, up balanced, right performance, red);
      // click = next profile, named in the tooltip for a moment
      IconBtn {
        id: ppBtn
        visible: Rice.power && Sys.powerAvailable   // programs.pharnavos.powerProfiles, and a daemon to talk to
        onClicked: { Sys.cycleProfile(); root.tipFor(this, true); tipHold.restart() }
        onContainsMouseChanged: root.tipFor(this, containsMouse || tipHold.running)
        Icon {
          d: "M4 18a8 8 0 1 1 16 0" + (Sys.profile === "performance" ? "M12 18l5-3" : Sys.profile === "power-saver" ? "M12 18l-5-3" : "M12 18l0-7")
          c: Sys.profile === "performance" ? root.red : parent.fg
        }
      }
      IconBtn {
        on: Rice.notifCount > 0
        onClicked: Rice.notifShowAll = !Rice.notifShowAll
        Icon { d: "M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 21h4"; c: parent.fg }
        // open: a red ring (outline kept, never a solid fill)
        Rectangle { anchors.fill: parent; radius: 17; color: "transparent"; border { width: 1.5; color: root.red } visible: Rice.notifShowAll }
        Rectangle { visible: Rice.notifCount > 0 && !Rice.notifShowAll; x: 21; y: 6; width: 8; height: 8; radius: 4; color: root.red }
      }
      // load as two qvevri: wine rises with CPU (red) and RAM (cream); hover for numbers
      MouseArea {
        id: loadHit
        width: loadRow.width + 12; height: 40; hoverEnabled: true
        onContainsMouseChanged: root.tipFor(this, containsMouse)
        Row {
          id: loadRow
          anchors.centerIn: parent; spacing: 12
          Repeater {
            // a chip and a memory stick stamped into the clay
            model: [["M7 7h10v10H7zM10 10h4v4h-4zM9 3v4M15 3v4M9 17v4M15 17v4M3 9h4M3 15h4M17 9h4M17 15h4", Sys.cpu, "#B0151F"],
                    ["M3 7h18v8H3zM6 15v3M10 15v3M14 15v3M18 15v3M7 10h2v2H7zM11 10h2v2h-2zM15 10h2v2h-2z", Sys.ram, "#C9C1C4"]]
            // the chip / memory-stick icon stamped into each jar
            Item {
              required property var modelData
              width: 24; height: 36
              Qvevri { anchors.centerIn: parent; level: parent.modelData[1]; wine: parent.modelData[2]; icon: parent.modelData[0]; scale: 1.5 }
            }
          }
        }
      }
      IconBtn {
        // St. Nino's grapevine cross — opens the control centre
        onClicked: Rice.ccOpen = !Rice.ccOpen
        Shape {
          anchors.centerIn: parent; width: 20; height: 26
          preferredRendererType: Shape.CurveRenderer
          ShapePath { strokeColor: root.red; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap; PathSvg { path: "M10 2 C9.4 9 10.6 17 10 24M2 11 Q10 6 18 11" } }
        }
      }
    }
  }

  // one tooltip under whichever status item is hovered (or just clicked, for the power profile)
  property Item tipItem: null
  function tipFor(item, on) { if (on) root.tipItem = item; else if (root.tipItem === item && !tipHold.running) root.tipItem = null }
  Timer { id: tipHold; interval: 1600; onTriggered: if (!root.tipItem?.containsMouse) root.tipItem = null }
  readonly property string tipText: {
    const t = root.tipItem;
    if (t === loadHit) return "CPU " + Sys.cpu + "%  ·  RAM " + Sys.ramUsedG + " / " + Sys.ramTotalG + " G";
    if (t === netBtn) return !Sys.online ? Rice.t("კავშირი არ არის", "Offline")
      : "↓ " + Sys.rate(Sys.rxRate) + "   ↑ " + Sys.rate(Sys.txRate) + "\n" + (Sys.ssid ? Sys.ssid + " · " + Sys.signal + "%" : Rice.t("სადენიანი", "Wired"));
    if (t === btBtn) return !btBtn.on ? Rice.t("Bluetooth გამორთულია", "Bluetooth is off")
      : btBtn.devs.length ? btBtn.devs.map(d => d.name + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : "")).join("\n")
      : Rice.t("მოწყობილობა არ არის", "No device connected");
    if (t === ppBtn) return ({ "power-saver": Rice.t("ენერგიის დაზოგვა", "Power saver"), "balanced": Rice.t("ბალანსი", "Balanced"),
                               "performance": Rice.t("მარდად", "Performance") })[Sys.profile] ?? Sys.profile;
    return "";
  }
  Rectangle {
    visible: root.tipItem !== null && root.tipText !== ""
    // centred under the item, but kept on screen (they sit near the right edge)
    x: root.tipItem ? Math.min(root.width - width - 12, root.tipItem.mapToItem(root.contentItem, 0, 0).x + root.tipItem.width / 2 - width / 2) : 0; y: 52
    width: tipT.implicitWidth + 28; height: tipT.implicitHeight + 18; radius: 10
    color: "#0E0B0D"; border.color: "#3A2E33"
    Text {
      id: tipT; anchors.centerIn: parent
      text: root.tipText; lineHeight: 1.3; horizontalAlignment: Text.AlignHCenter
      color: root.cream; font { family: root.mono; pixelSize: 12; bold: true }
    }
  }


  // ---- little components ---------------------------------------------------
  component IconBtn: MouseArea {
    property bool on: true
    readonly property color fg: containsMouse ? "#FFFFFF" : on ? "#C9C1C4" : "#5A4E53"
    width: 34; height: 34; hoverEnabled: true
    Rectangle { anchors.fill: parent; radius: 17; color: parent.containsMouse ? "#1A1517" : "transparent" }
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
