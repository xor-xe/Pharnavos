// Bar popups: hovering a status icon (or the wine jars) drops a panel straight off the bar: square top
// with a glowing red edge, soft bottom corners, a notch pointing at the icon. It stays open while the
// pointer is on the icon or the panel and closes a moment after it leaves both. Its contents (and the
// commands that fill them) exist only while it is open.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
  id: pops
  required property var bar                // the SunBar window
  property string key: ""                  // jars | wifi | bt | power | sound
  property Item anchorItem: null
  // open while the pointer is on an icon or on the popup; the two can report in either order
  property bool overIcon: false
  property bool overPop: false
  function hover(k, item, on) {
    overIcon = on;
    if (on) { key = k; anchorItem = item }
    settle();
  }
  function settle() { if (overIcon || overPop) closeT.stop(); else closeT.restart() }
  Timer { id: closeT; interval: 350; onTriggered: pops.key = "" }

  readonly property color red: Theme.red
  readonly property color cream: Theme.cream
  readonly property color grey: "#8C8186"
  readonly property string mono: "FiraCode Nerd Font"

  readonly property real w: ({ jars: 290, wifi: 360, bt: 300, power: 300, sound: 300 })[key] ?? 290
  readonly property real cx: anchorItem ? anchorItem.mapToItem(bar.contentItem, anchorItem.width / 2, 0).x : 0
  // kept on screen; at the right edge it sits flush against it, like the control centre
  readonly property bool edge: cx + w / 2 >= bar.width - 8
  readonly property bool shown: key !== "" && anchorItem !== null
  x: edge ? bar.width - w : Math.max(8, cx - w / 2)
  y: 46
  width: shown ? w : 0; height: shown ? frame.height : 0
  visible: shown
  HoverHandler { onHoveredChanged: { pops.overPop = hovered; pops.settle() } }

  Rectangle {
    id: frame
    width: pops.w; height: body.implicitHeight + 26
    color: "#0B090A"; border.color: "#3A2E33"
    bottomLeftRadius: 22; bottomRightRadius: pops.edge ? 0 : 22
    // the glowing red edge along the bar, and the notch above the icon
    Rectangle {
      width: parent.width; height: 2; color: pops.red
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: pops.red; shadowBlur: 0.6; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
    }
    Shape {
      x: pops.cx - pops.x - 5; y: 2; width: 10; height: 6; preferredRendererType: Shape.CurveRenderer
      ShapePath { fillColor: pops.red; strokeWidth: 0; strokeColor: "transparent"; PathSvg { path: "M0 0 L10 0 L5 6 Z" } }
    }
    Column {
      id: body
      x: 14; y: 12; width: parent.width - 28
      Text {
        bottomPadding: 2
        text: ({ jars: Rice.t("მარანი", "Cellar"), wifi: "Wi-Fi", bt: "Bluetooth", power: Rice.t("ენერგია", "Power"), sound: Rice.t("ხმა", "Sound") })[pops.key] ?? ""
        color: pops.red; font { family: Theme.labelFor(text); pixelSize: 11; letterSpacing: 1.4 }
      }
      Loader {
        width: parent.width
        active: pops.shown
        sourceComponent: ({ jars: jarsC, wifi: wifiC, bt: btC, power: powerC, sound: soundC })[pops.key] ?? null
      }
    }
  }

  // ---- shared pieces ---------------------------------------------------------------------------
  function hm(sec) {   // seconds → "3 სთ 40 წთ"
    const m = Math.round(sec / 60), h = Math.floor(m / 60);
    return (h ? h + Rice.t(" სთ ", " h ") : "") + (m % 60) + Rice.t(" წთ", " min");
  }
  function rateParts(b) {
    return b >= 1048576 ? [(b / 1048576).toFixed(1), "MB/s"] : b >= 1024 ? [String(Math.round(b / 1024)), "KB/s"] : [String(Math.round(b)), "B/s"];
  }
  readonly property var paths: ({
    down: "M12 4v14M6 12l6 6 6-6", up: "M12 20V6M6 12l6-6 6 6",
    spk: "M4 9h4l5-4v14l-5-4H4zM17 9a4 4 0 0 1 0 6M19.5 6.5a8 8 0 0 1 0 11",
    mic: "M9 4a3 3 0 0 1 6 0v6a3 3 0 0 1-6 0zM5 10a7 7 0 0 0 14 0M12 17v4",
    head: "M4 15v-3a8 8 0 0 1 16 0v3M4 15h3v5H4zM17 15h3v5h-3z",
    mouse: "M7 9a5 5 0 0 1 10 0v6a5 5 0 0 1-10 0zM12 4v5",
    pad: "M6 9h12a4 4 0 0 1 4 4v1a3 3 0 0 1-5 2l-2-2H9l-2 2a3 3 0 0 1-5-2v-1a4 4 0 0 1 4-4zM8 12v2M7 13h2M16 12h.01M18 14h.01",
    keys: "M3 7h18v10H3zM7 11h.01M11 11h.01M15 11h.01M7 14h10",
    phone: "M8 3h8v18H8zM11 18h2",
    bt: "M7 7l10 10-5 4V3l5 4L7 17",
    leaf: "M5 19c0-8 6-14 14-14 0 8-6 14-14 14zM5 19l7-7",
    scale: "M12 4v16M5 8h14M5 8l-2 6h4zM19 8l-2 6h4z",
    bolt: "M13 3L5 14h6l-1 7 8-11h-6z"
  })
  component Glyph: Shape {
    property string d
    property color c
    property real stroke: 2
    width: 24; height: 24; preferredRendererType: Shape.CurveRenderer
    ShapePath { strokeColor: c; strokeWidth: stroke; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; PathSvg { path: d } }
  }
  // a row: icon (or a small jar) · name · big number, a level line in its colour, a detail line
  component Line: Item {
    id: ln
    property string icon: ""
    property real jar: -1                  // ≥ 0: a jar with this level instead of an icon
    property color jarWine: pops.red
    property bool jarHot: false
    property string name
    property string num: ""
    property string unit: ""
    property real level: -1
    property color col: pops.cream
    property string sub: ""
    property bool dim: false
    property bool first: false
    width: parent ? parent.width : 0; height: lc.implicitHeight + 16
    opacity: dim ? 0.55 : 1
    Rectangle { visible: !ln.first; width: parent.width; height: 1; color: "#211A1E" }
    Column {
      id: lc
      y: 8; width: parent.width; spacing: 5
      Item {
        width: parent.width; height: 26
        Item {
          width: 24; height: 26
          Glyph { visible: ln.jar < 0 && ln.icon !== ""; anchors.centerIn: parent; d: ln.icon; c: ln.col }
          Qvevri { visible: ln.jar >= 0; anchors.centerIn: parent; level: ln.jar; wine: ln.jarWine; glow: true; alarm: ln.jarHot; pulse: false }
        }
        Text {
          x: 34; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 34 - numRow.width - 8
          elide: Text.ElideRight; textFormat: Text.PlainText; text: ln.name
          color: pops.cream; font { family: Theme.sans; pixelSize: 13; weight: Font.Bold }
        }
        Row {
          id: numRow
          anchors { right: parent.right; verticalCenter: parent.verticalCenter }
          spacing: 3
          Text { id: numT; text: ln.num; color: ln.col; font { family: Theme.digits; pixelSize: 24 } }
          Text { anchors.baseline: numT.baseline; text: ln.unit; color: ln.col; font { family: Theme.sans; pixelSize: 11 } }
        }
      }
      Rectangle {
        visible: ln.level >= 0
        x: 34; width: parent.width - 34; height: 4; radius: 2; color: "#1E181B"
        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, ln.level / 100)); height: 4; radius: 2; color: ln.col
          Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
      }
      Text {
        visible: ln.sub !== ""
        x: 34; width: parent.width - 34; elide: Text.ElideRight; textFormat: Text.PlainText
        text: ln.sub; color: pops.grey; font { family: pops.mono; pixelSize: 11 }
      }
    }
  }
  component Foot: Text {
    width: parent ? parent.width : 0; topPadding: 6; horizontalAlignment: Text.AlignRight
    color: pops.grey; font { family: pops.mono; pixelSize: 10 }
  }

  // ---- the jars: battery, processor, memory ------------------------------------------------------
  Component {
    id: jarsC
    Column {
      id: jc
      readonly property var dev: UPower.displayDevice
      readonly property bool batOn: !!dev && dev.ready && dev.isLaptopBattery && dev.isPresent
      readonly property real pct: Math.round(dev ? (dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 0)
      readonly property bool charging: dev?.state === UPowerDeviceState.Charging || dev?.state === UPowerDeviceState.PendingCharge
      readonly property bool low: pct <= 15 && !charging
      // cores and clock, read while the popup is open
      property int cores: 0
      property int mhz: 0
      FileView {
        id: cpuinfo; path: "/proc/cpuinfo"
        onLoaded: {
          const m = text().match(/^cpu MHz\s*:\s*([\d.]+)/gm) || [];
          jc.cores = m.length;
          jc.mhz = m.length ? Math.round(m.map(l => Number(l.split(":")[1])).reduce((a, b) => a + b, 0) / m.length) : 0;
        }
      }
      Timer { interval: 2000; running: true; repeat: true; onTriggered: cpuinfo.reload() }
      Line {
        visible: jc.batOn; first: true
        jar: jc.pct; jarWine: "#E0607E"; jarHot: jc.low
        name: Rice.t("ბატარეა", "Battery"); num: String(jc.pct); unit: "%"; level: jc.pct
        col: jc.low ? pops.red : "#E0607E"
        sub: jc.charging ? Rice.t("იტენება", "charging") + (jc.dev.timeToFull > 0 ? Rice.t(" · სავსე ", " · full in ") + pops.hm(jc.dev.timeToFull) + Rice.t("-ში", "") : "")
           : (jc.low ? Rice.t("დაბალია · ", "low · ") : "") + (jc.dev?.timeToEmpty > 0 ? pops.hm(jc.dev.timeToEmpty) + Rice.t(" დარჩა", " left") : "")
      }
      Line {
        first: !jc.batOn
        jar: Sys.cpu; jarWine: "#B0151F"
        name: Rice.t("პროცესორი", "Processor"); num: String(Sys.cpu); unit: "%"; level: Sys.cpu; col: "#D8323F"
        sub: jc.cores ? jc.cores + Rice.t(" ბირთვი", " cores") + (jc.mhz ? " · " + (jc.mhz / 1000).toFixed(1) + " GHz" : "") : ""
      }
      Line {
        jar: Sys.ram; jarWine: "#C9C1C4"
        name: Rice.t("მეხსიერება", "Memory"); num: Sys.ramUsedG.toFixed(1); unit: "GB"; level: Sys.ram; col: "#C9C1C4"
        sub: Sys.ramUsedG.toFixed(1) + " / " + Sys.ramTotalG.toFixed(1) + " GB"
      }
    }
  }

  // ---- Wi-Fi: signal arcs, the network, and the last minute of traffic ----------------------------
  Component {
    id: wifiC
    Column {
      id: wc
      spacing: 0
      property string band: ""
      property string ip: ""
      // band, link speed and address: asked once when the popup opens
      Process {
        running: true
        command: ["nmcli", "-t", "-f", "IN-USE,FREQ,RATE", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
          onStreamFinished: {
            const l = text.split("\n").find(l => l.startsWith("*:"));
            if (!l) return;
            const p = l.split(":"), f = parseInt(p[1]);
            wc.band = (f >= 5900 ? "6 GHz" : f >= 4900 ? "5 GHz" : "2.4 GHz") + (p[2] ? " · " + p[2].replace("Mbit/s", "Mb/s") : "");
          }
        }
      }
      Process {
        running: Sys.iface !== ""
        command: ["nmcli", "-g", "IP4.ADDRESS", "dev", "show", Sys.iface]
        stdout: StdioCollector { onStreamFinished: wc.ip = text.split("\n")[0].split("/")[0] }
      }
      Item {
        width: parent.width; height: 74
        // four arcs, lit by the signal
        Shape {
          id: arcs
          y: 8; width: 72; height: 58; preferredRendererType: Shape.CurveRenderer
          readonly property int lit: !Sys.online ? 0 : !Sys.ssid ? 4 : Sys.signal >= 75 ? 4 : Sys.signal >= 50 ? 3 : Sys.signal >= 25 ? 2 : 1
          ShapePath { strokeColor: arcs.lit >= 1 ? pops.red : "#2E272A"; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap; PathSvg { path: "M27 52 A9 9 0 0 1 45 52" } }
          ShapePath { strokeColor: arcs.lit >= 2 ? pops.red : "#2E272A"; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap; PathSvg { path: "M18 50 A18 18 0 0 1 54 50" } }
          ShapePath { strokeColor: arcs.lit >= 3 ? pops.red : "#2E272A"; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap; PathSvg { path: "M9 48 A27 27 0 0 1 63 48" } }
          ShapePath { strokeColor: arcs.lit >= 4 ? pops.red : "#2E272A"; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap; PathSvg { path: "M1 46 A35 35 0 0 1 71 46" } }
          layer.enabled: true
          layer.effect: MultiEffect { shadowEnabled: true; shadowColor: pops.red; shadowBlur: 0.4; shadowOpacity: 0.6; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
        }
        Column {
          x: 88; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 88; spacing: 4
          Text {
            width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
            text: !Sys.online ? Rice.t("კავშირი არ არის", "Offline") : Sys.ssid || Rice.t("სადენიანი", "Wired")
            color: "#FFFFFF"; font { family: Theme.sans; pixelSize: 17; weight: Font.ExtraBold }
          }
          Text {
            visible: Sys.online && Sys.ssid !== ""
            text: Rice.t("სიგნალი ", "signal ") + Sys.signal + "%" + (wc.band ? " · " + wc.band : "")
            color: pops.grey; font { family: pops.mono; pixelSize: 11 }
          }
          Text { visible: wc.ip !== ""; text: wc.ip; color: pops.grey; font { family: pops.mono; pixelSize: 11 } }
        }
      }
      // download, then upload: each its own graph, scaled to the busiest moment of the minute
      Repeater {
        model: [[Rice.t("↓ ჩამოტვირთვა", "↓ download"), "rx", pops.cream], [Rice.t("↑ ატვირთვა", "↑ upload"), "tx", "#E0607E"]]
        Item {
          id: flow
          required property var modelData
          required property int index
          readonly property var hist: modelData[1] === "rx" ? Sys.rxHist : Sys.txHist
          readonly property real now: modelData[1] === "rx" ? Sys.rxRate : Sys.txRate
          readonly property real peak: Math.max(65536, ...hist)
          width: parent.width; height: 84
          Rectangle { width: parent.width; height: 1; color: "#211A1E"; y: flow.index ? 4 : 0 }
          Text { y: 12; text: flow.modelData[0]; color: pops.grey; font { family: Theme.labelFor(text); pixelSize: 11; weight: Font.DemiBold } }
          Row {
            anchors.right: parent.right; y: 8; spacing: 3
            Text { id: rt; text: pops.rateParts(flow.now)[0]; color: flow.modelData[2]; font { family: Theme.digits; pixelSize: 24 } }
            Text { anchors.baseline: rt.baseline; text: pops.rateParts(flow.now)[1]; color: pops.grey; font { family: pops.mono; pixelSize: 10 } }
          }
          Shape {
            id: graph
            y: 38; width: parent.width; height: 40; preferredRendererType: Shape.CurveRenderer
            readonly property var pts: flow.hist.map((v, i) => Qt.point(i / (flow.hist.length - 1) * width, height - 2 - Math.min(1, v / flow.peak) * (height - 4)))
            readonly property color c: flow.modelData[2]
            ShapePath {
              strokeWidth: 0; strokeColor: "transparent"; fillColor: Qt.rgba(graph.c.r, graph.c.g, graph.c.b, 0.14)
              PathPolyline { path: [Qt.point(0, graph.height)].concat(graph.pts, [Qt.point(graph.width, graph.height)]) }
            }
            ShapePath {
              strokeColor: graph.c; strokeWidth: 1.5; fillColor: "transparent"; joinStyle: ShapePath.RoundJoin
              PathPolyline { path: graph.pts }
            }
          }
        }
      }
      Foot { text: Rice.t("ბოლო წუთი · დააჭირე: ქსელის პარამეტრები", "last minute · click: network settings") }
    }
  }

  // ---- Bluetooth: devices, with their batteries ---------------------------------------------------
  Component {
    id: btC
    Column {
      id: bc
      readonly property bool on: Bluetooth.defaultAdapter?.enabled ?? false
      readonly property var devs: Bluetooth.devices.values.filter(d => d.paired || d.connected).sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0))
      function iconFor(d) {
        const i = (d.icon || "").toLowerCase();
        return /head|audio|ear/.test(i) ? pops.paths.head : /gam|joy/.test(i) ? pops.paths.pad : /mouse/.test(i) ? pops.paths.mouse
             : /keyboard/.test(i) ? pops.paths.keys : /phone/.test(i) ? pops.paths.phone : pops.paths.bt;
      }
      Text {
        visible: !bc.on || bc.devs.length === 0
        topPadding: 8; bottomPadding: 8
        text: !bc.on ? Rice.t("Bluetooth გამორთულია", "Bluetooth is off") : Rice.t("დაწყვილებული მოწყობილობა არ არის", "No paired devices")
        color: pops.grey; font { family: Theme.sans; pixelSize: 13 }
      }
      Repeater {
        model: bc.on ? bc.devs : []
        Line {
          required property var modelData
          required property int index
          first: index === 0
          icon: bc.iconFor(modelData)
          name: modelData.name || modelData.address
          num: modelData.connected && modelData.batteryAvailable ? String(Math.round(modelData.battery * 100)) : ""
          unit: num ? "%" : ""
          level: modelData.connected && modelData.batteryAvailable ? modelData.battery * 100 : -1
          col: modelData.connected ? (index === 0 ? "#E0607E" : pops.cream) : pops.grey
          dim: !modelData.connected
          sub: modelData.connected ? Rice.t("მიერთებულია", "connected") : Rice.t("დაწყვილებულია · არ არის მიერთებული", "paired · not connected")
        }
      }
      Foot { text: Rice.t("დააჭირე: Bluetooth-ის მართვა", "click: Bluetooth manager") }
    }
  }

  // ---- energy: a dial like the bar's gauge; each third picks a profile -----------------------------
  Component {
    id: powerC
    Column {
      id: pc
      readonly property var profs: ["power-saver", "balanced", "performance"]
      readonly property var cols: ["#6FBF73", "#EDE6DA", pops.red]     // green leaf, white, red
      readonly property var names: [Rice.t("ენერგიის დაზოგვა", "Power saver"), Rice.t("ბალანსი", "Balanced"), Rice.t("მარდად", "Performance")]
      readonly property var tips: [Rice.t("ჩუმი · ბატარეა დიდხანს ძლებს", "quiet · the battery lasts"), Rice.t("ყოველდღიური", "everyday"), Rice.t("მაქსიმალური სიჩქარე · მეტი ხმაური", "full speed · more fan noise")]
      readonly property var icons: [pops.paths.leaf, pops.paths.scale, pops.paths.bolt]
      readonly property int cur: Math.max(0, profs.indexOf(Sys.profile))
      property int hov: -1                                          // the third under the pointer
      readonly property int show: hov >= 0 ? hov : cur
      Item {
        id: dial
        width: 252; height: 146; anchors.horizontalCenter: parent.horizontalCenter
        readonly property real cx: 126
        readonly property real cy: 128
        readonly property real big: 104
        readonly property real small: 66
        function at(a, r) { return Qt.point(cx + r * Math.cos(a), cy - r * Math.sin(a)) }
        function seg(k) {
          const a0 = Math.PI - k * Math.PI / 3 - 0.03, a1 = Math.PI - (k + 1) * Math.PI / 3 + 0.03;
          const p0 = at(a0, big), p1 = at(a1, big), p2 = at(a1, small), p3 = at(a0, small);
          return `M${p0.x} ${p0.y} A${big} ${big} 0 0 1 ${p1.x} ${p1.y} L${p2.x} ${p2.y} A${small} ${small} 0 0 0 ${p3.x} ${p3.y} Z`;
        }
        // ticks around the rim
        Shape {
          anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: "#3A2E33"; strokeWidth: 1.2; fillColor: "transparent"
            PathSvg {
              path: Array.from({ length: 19 }, (_, i) => { const a = Math.PI - i * Math.PI / 18, p = dial.at(a, dial.big + 6), q = dial.at(a, dial.big + (i % 3 ? 10 : 14)); return `M${p.x} ${p.y} L${q.x} ${q.y}` }).join(" ")
            }
          }
        }
        Repeater {
          model: 3
          Shape {
            id: segS
            required property int index
            readonly property bool on: index === pc.cur
            anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
            ShapePath {
              fillColor: segS.on ? pc.cols[segS.index] : pc.hov === segS.index ? "#241C20" : "#1A1416"
              strokeColor: segS.on ? pc.cols[segS.index] : pc.hov === segS.index ? pc.cols[segS.index] : "#3A2E33"; strokeWidth: 1.2
              PathSvg { path: dial.seg(segS.index) }
            }
            layer.enabled: on
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: pc.cols[index]; shadowBlur: 0.7; shadowOpacity: 0.8; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
          }
        }
        Repeater {
          model: 3
          Glyph {
            required property int index
            readonly property point p: dial.at(Math.PI - (index + 0.5) * Math.PI / 3, (dial.big + dial.small) / 2)
            x: p.x - 10; y: p.y - 10; scale: 0.84
            d: pc.icons[index]; c: index === pc.cur ? "#070607" : pops.grey; stroke: 2.2
          }
        }
        // the needle
        Rectangle {
          x: dial.cx - 1.5; y: dial.cy - height; width: 3; height: dial.small - 14; radius: 1.5; color: "#FFFFFF"
          transformOrigin: Item.Bottom
          rotation: (pc.cur + 0.5) * 60 - 90
          Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
        }
        Rectangle { x: dial.cx - 7; y: dial.cy - 7; width: 14; height: 14; radius: 7; color: pops.red }
        Rectangle { x: dial.cx - 3; y: dial.cy - 3; width: 6; height: 6; radius: 3; color: "#070607" }
        // pointing picks a third by its angle; clicking chooses it
        MouseArea {
          anchors.fill: parent; hoverEnabled: true
          function third(m) {
            const dx = m.x - dial.cx, dy = dial.cy - m.y, r = Math.hypot(dx, dy);
            if (dy < -4 || r < dial.small - 6 || r > dial.big + 16) return -1;
            return Math.min(2, Math.max(0, Math.floor((Math.PI - Math.atan2(Math.max(dy, 0), dx)) / (Math.PI / 3))));
          }
          cursorShape: pc.hov >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
          onPositionChanged: m => pc.hov = third(m)
          onExited: pc.hov = -1
          onClicked: m => { const k = third(m); if (k >= 0) Sys.setProfile(pc.profs[k]) }
        }
      }
      Text {
        width: parent.width; horizontalAlignment: Text.AlignHCenter
        text: pc.names[pc.show]; color: pc.cols[pc.show]; font { family: Theme.sans; pixelSize: 15; weight: Font.ExtraBold }
      }
      Text {
        width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 2; bottomPadding: 6
        text: pc.tips[pc.show]; color: pops.grey; font { family: pops.mono; pixelSize: 11 }
      }
      Foot { horizontalAlignment: Text.AlignHCenter; text: Rice.t("აირჩიე ნაწილი", "pick a third") }
    }
  }

  // ---- sound: the output and microphone in use, live ---------------------------------------------
  Component {
    id: soundC
    Column {
      id: sc
      readonly property PwNode sink: Pipewire.defaultAudioSink
      readonly property PwNode source: Pipewire.defaultAudioSource
      PwObjectTracker { objects: [sc.sink, sc.source] }
      Repeater {
        model: [[sc.sink, pops.paths.spk, Rice.t("გამომავალი", "output"), pops.red], [sc.source, pops.paths.mic, Rice.t("შემავალი", "input"), "#C9C1C4"]]
        Item {
          id: sl
          required property var modelData
          required property int index
          readonly property PwNode node: modelData[0]
          readonly property bool muted: node?.audio?.muted ?? false
          readonly property real vol: node?.audio?.volume ?? 0
          readonly property color col: muted ? "#5A4E53" : modelData[3]
          visible: node !== null
          width: parent.width; height: 70
          Rectangle { visible: sl.index > 0; width: parent.width; height: 1; color: "#211A1E" }
          // click the speaker / microphone: mute
          MouseArea {
            id: muteB
            x: 0; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34; hoverEnabled: true
            onClicked: if (sl.node?.audio) sl.node.audio.muted = !sl.node.audio.muted
            Rectangle { anchors.fill: parent; radius: 17; color: "#120E10"; border.color: muteB.containsMouse ? pops.red : "#2A2024" }
            Glyph { anchors.centerIn: parent; scale: 0.8; d: sl.modelData[1] + (sl.muted ? "M3 3l18 18" : ""); c: sl.col }
          }
          Text {
            x: 46; y: 8; width: parent.width - 46 - 44; elide: Text.ElideRight; textFormat: Text.PlainText
            text: sl.node?.description || sl.node?.nickname || sl.node?.name || ""
            color: pops.cream; font { family: Theme.sans; pixelSize: 13; weight: Font.Bold }
          }
          Text { x: 46; y: 26; text: sl.modelData[2]; color: pops.grey; font { family: pops.mono; pixelSize: 10 } }
          // drag the level
          Item {
            id: track
            x: 46; y: 46; width: parent.width - 46 - 44; height: 14
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: "#1E181B" }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.min(1, sl.vol); height: 6; radius: 3; color: sl.col }
            Rectangle {
              x: parent.width * Math.min(1, sl.vol) - 7; anchors.verticalCenter: parent.verticalCenter
              width: 14; height: 14; radius: 7; color: pops.cream
            }
            MouseArea {
              anchors.fill: parent; anchors.margins: -6
              function set(m) { if (sl.node?.audio) { sl.node.audio.volume = Math.max(0, Math.min(1, (m.x - 6) / track.width)); sl.node.audio.muted = false } }
              onPressed: m => set(m)
              onPositionChanged: m => { if (pressed) set(m) }
            }
          }
          Text {
            anchors.right: parent.right; anchors.verticalCenter: track.verticalCenter
            text: sl.muted ? "—" : String(Math.round(sl.vol * 100)); color: sl.col; font { family: Theme.digits; pixelSize: 20 }
          }
        }
      }
    }
  }
}
