// Control centre: unfurls from St. Nino's cross. Tabs: მართვა (connections, sound, calendar,
// tasks, session) and ფონი (wallpaper settings). Port of the ControlCenter + CCWall prototypes.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

PanelWindow {
  id: cc
  required property var bar
  screen: bar.screen
  WlrLayershell.namespace: "pharnavos-cc"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: Rice.ccOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; right: true }
  margins { top: 46; right: 0 }
  // fixed-size surface (30 px slack for the cloth's sway): the panel grows inside it, so opening a
  // list never resizes the Wayland surface — a resize is what made the panel flash
  // 300 px on the left for notices (Wi-Fi status…), 30 px slack for the cloth's sway
  implicitWidth: 300 + 680 + 30; implicitHeight: (screen?.height ?? 1440) - 46
  color: "transparent"
  // stays mapped until the close animation has finished (an unmap mid-way makes Hyprland fade a stale frame)
  property bool mapped: false
  visible: mapped
  mask: Region { item: panel; Region { item: notice } }

  // ---- flag entrance: p = open progress, clk = ripple clock -------------------------------
  property real p: 0
  property real clk: 9
  readonly property real rippleT: Rice.ccOpen ? Math.max(0, clk - 0.4) : clk + 0.15
  // once the ripple has died out the real panel is shown (crisp text, no shader)
  readonly property bool settled: Rice.ccOpen && !openA.running && clk > 2.0
  NumberAnimation { id: openA; target: cc; property: "p"; to: 1; duration: 720; easing.type: Easing.OutCubic }
  NumberAnimation { id: closeA; target: cc; property: "p"; to: 0; duration: 380; easing.type: Easing.InOutQuad; onFinished: if (!Rice.ccOpen) cc.mapped = false }
  NumberAnimation { id: clkA; target: cc; property: "clk"; from: 0; to: 2.2; duration: 2200 }
  Connections {
    target: Rice
    function onCcOpenChanged() {
      if (Rice.ccOpen) { cc.mapped = true; closeA.stop(); openA.start(); } else { openA.stop(); closeA.start(); }
      clkA.restart();
    }
  }

  readonly property color red: Theme.red
  readonly property color cream: Theme.cream
  readonly property color grey: "#8C8186"
  readonly property color line: "#2A2226"
  readonly property color card: "#0E0B0D"
  property string tab: Quickshell.env("PHARNAVOS_CCTAB") || "main"

  IpcHandler { target: "cc-ui"; function tab(t: string): void { cc.tab = t } function list(k: string): void { if (k === "out" || k === "in") cc.soundOpen = cc.soundOpen === k ? "" : k; else cc.list = k } }

  HyprlandFocusGrab { windows: [cc, cc.bar]; active: Rice.ccOpen; onCleared: Rice.ccOpen = false }

  // ---- data (refreshed while open) -----------------------------------------------
  property var now: new Date()
  property string uptime: ""
  property string gpu: ""
  property bool wifiOn: false
  property var nets: []
  Timer {
    interval: 1000; running: Rice.ccOpen; repeat: true; triggeredOnStart: true
    property int n: 0
    onRunningChanged: if (running) { n = 0; netProc.rescan = "no"; netProc.running = true; savedProc.running = true }   // cached list: instant
    onTriggered: {
      cc.now = new Date(); upFile.reload();
      if (n++ % 10 === 0) { gpuProc.running = true; radioProc.running = true; }
      if (n === 2 || n % 10 === 0) { netProc.rescan = "auto"; netProc.running = true }        // then a real scan
    }
  }
  FileView { path: "/proc/sys/kernel/hostname"; onLoaded: cc.host = text().trim() }
  property string host: ""
  FileView { id: upFile; path: "/proc/uptime"; onLoaded: { const s = Number(text().split(" ")[0]); cc.uptime = Math.floor(s / 86400) + "d " + Math.floor(s % 86400 / 3600) + "h" } }
  Process { id: gpuProc; command: ["nvidia-smi", "--query-gpu=name,temperature.gpu", "--format=csv,noheader"]; stdout: StdioCollector { onStreamFinished: { const p = text.trim().split(", "); if (p.length > 1) cc.gpu = p[0].replace("NVIDIA GeForce ", "") + " " + p[1] + "°" } } }
  Component.onCompleted: radioProc.running = true
  Process { id: radioProc; command: ["nmcli", "radio", "wifi"]; stdout: StdioCollector { onStreamFinished: cc.wifiOn = text.trim() === "enabled" } }
  Process {
    id: netProc
    property string rescan: "no"
    command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "dev", "wifi", "list", "--rescan", rescan]
    stdout: StdioCollector {
      onStreamFinished: {
        // one row per network name: the same SSID shows up once per access point, and the one we are
        // connected to is often not the first, so merge them (connected if any is, strongest signal)
        const by = {};
        for (const l of text.trim().split("\n")) {
          const p = l.split(":"), ssid = p.slice(3).join(":").replace(/\\:/g, ":");
          if (!ssid) continue;
          const n = by[ssid] ?? (by[ssid] = { ssid, use: false, sig: 0, sec: false, ent: false });
          n.use = n.use || p[0] === "*"; n.sig = Math.max(n.sig, Number(p[1])); n.sec = n.sec || p[2] !== "";
          n.ent = n.ent || /802\.1X/.test(p[2]);   // enterprise login (eduroam…): needs a username too
        }
        cc.nets = Object.values(by).sort((a, b) => b.use - a.use || b.sig - a.sig).slice(0, 6);
      }
    }
  }
  // network names (SSIDs) of saved Wi-Fi profiles: those connect without asking for the password
  // again. By SSID, not profile name: a profile called "Home" can be for "MyNetwork-5G".
  property var saved: []
  Process {
    id: savedProc
    command: ["sh", "-c", "nmcli -g UUID,TYPE connection show | while IFS=: read -r u t; do [ \"$t\" = 802-11-wireless ] && nmcli -g 802-11-wireless.ssid connection show uuid \"$u\"; done"]
    stdout: StdioCollector { onStreamFinished: cc.saved = text.split("\n").filter(l => l !== "") }
  }

  // ---- joining a network ---------------------------------------------------------------------
  property string pwFor: ""       // network whose password field is open
  function pick(net) {
    if (net.use) return;
    if (net.ent) { Quickshell.execDetached([Rice.terminal, "-e", "nmtui", "connect", net.ssid]); Rice.ccOpen = false; return }
    if (net.sec && !cc.saved.includes(net.ssid)) { cc.pwFor = cc.pwFor === net.ssid ? "" : net.ssid; return }
    cc.join(net.ssid, "");
  }
  function join(ssid, pw) {
    cc.pwFor = "";
    cc.say(Rice.t("ვუერთდები ", "Connecting to ") + ssid + "…", false);
    joinProc.ssid = ssid; joinProc.fresh = !cc.saved.includes(ssid);
    // note: the password is an nmcli argument (visible to other local users for a moment);
    // a secret agent or passwd-file would avoid that
    joinProc.command = ["nmcli", "dev", "wifi", "connect", ssid].concat(pw ? ["password", pw] : []);
    joinProc.running = true;
  }
  Process {
    id: joinProc
    property string ssid
    property bool fresh
    stderr: StdioCollector { id: joinErr }
    onExited: code => {
      if (code === 0) { cc.say(Rice.t("მიერთებულია: ", "Connected: ") + ssid, true); netProc.running = true; savedProc.running = true; return }
      // a wrong password leaves a half-made profile behind: remove it and ask again
      if (fresh) cc.sh(["nmcli", "connection", "delete", "id", ssid]);
      const wrong = /secrets|password|802-1x|4-way/i.test(joinErr.text);
      cc.say(wrong ? Rice.t("არასწორი პაროლი", "Wrong password") : Rice.t("ვერ დავუკავშირდი ", "Couldn't connect to ") + ssid, false, true);
      if (wrong) cc.pwFor = ssid;
    }
  }
  Process { id: run }
  function sh(cmd) { run.exec(cmd) }

  // toast
  property string toast: ""
  property bool toastOk: false
  property bool toastBad: false
  Timer { id: toastT; interval: 3200; onTriggered: cc.toast = "" }
  function say(t, ok, bad) { toast = t; toastOk = !!ok; toastBad = !!bad; toastT.restart() }

  // ---- the panel -------------------------------------------------------------------------
  ShaderEffect {
    x: panel.x; y: 0; width: panel.width; height: panel.height
    visible: !cc.settled
    mesh: GridMesh { resolution: Qt.size(24, 90) }
    property variant source: ShaderEffectSource { sourceItem: panel; hideSource: !cc.settled; live: true }
    property real p: Math.max(0.0001, cc.p)
    property real t: cc.rippleT
    property real amp: 1.0
    property size dim: Qt.size(width, height)
    vertexShader: "file://" + Quickshell.shellDir + "/shaders/flag.vert.qsb"
    fragmentShader: "file://" + Quickshell.shellDir + "/shaders/flag.frag.qsb"
  }

  Item {
    anchors.fill: parent

    // notices (Wi-Fi status…) hang to the left of the panel, like a tag on the cloth
    Item {
      id: notice
      visible: opacity > 0
      opacity: cc.toast !== "" && Rice.ccOpen ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 180 } }
      x: panel.x - width - 12; y: 14
      width: Math.min(280, noticeT.implicitWidth + 52); height: 52
      Rectangle { anchors.fill: parent; radius: 14; color: "#0B090A" }
      Stitch { anchors.fill: parent; inset: 5; stroke: 2; thread: cc.toastBad ? cc.red : cc.toastOk ? cc.cream : "#8C8186" }
      Rectangle { x: 18; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: cc.toastBad ? cc.red : cc.toastOk ? "#7BC47F" : cc.grey }
      Text {
        id: noticeT
        x: 34; width: parent.width - 48; anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight; text: cc.toast; color: cc.cream
        font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold }
      }
    }

    Rectangle {
      id: panel
      x: 300 + 30; y: 0
      // hangs straight off the bar: square top + right edge, one soft corner bottom-left
      width: 680; height: bodyFlick.height + 44
      radius: 0; bottomLeftRadius: 32
      color: "#070607"; border.color: cc.line
      Rectangle { width: parent.width - 1; x: 1; height: 2; color: "#070607" }   // hide the top border so it merges with the bar
      focus: Rice.ccOpen
      Keys.onEscapePressed: Rice.ccOpen = false

      // khevsur zigzag hem
      Row {
        x: 0; y: 0; clip: true; width: parent.width; height: 10; opacity: 0.85
        Repeater { model: Math.ceil(680 / 10); Shape { width: 10; height: 10; ShapePath { fillColor: cc.red; strokeWidth: 0; strokeColor: "transparent"; PathSvg { path: "M0 0 L5 5 L10 0 Z" } } } }
      }

      // scrolls when the panel is taller than the screen (small laptops); otherwise it never moves
      Flickable {
        id: bodyFlick
        x: 22; y: 22; width: parent.width - 44
        height: Math.min(body.height, cc.height - 44 - 8)
        contentHeight: body.height; clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
      Column {
        id: body
        width: bodyFlick.width; spacing: 14

        // header
        Item {
          width: parent.width; height: 62
          // seal: the owner's initial (ხ → Ⴞ) in asomtavruli, in a stitched ring
          Item {
            id: medal
            width: 48; height: 48; anchors.verticalCenter: parent.verticalCenter
            Shape {
              anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
              ShapePath {
                strokeColor: cc.red; strokeWidth: 2; fillColor: "#0E0B0D"
                strokeStyle: ShapePath.DashLine; dashPattern: [2, 1.5]
                PathAngleArc { centerX: 24; centerY: 24; radiusX: 22.5; radiusY: 22.5; startAngle: 0; sweepAngle: 360 }
              }
            }
            Text { anchors.centerIn: parent; anchors.verticalCenterOffset: 1; text: "Ⴞ"; color: cc.red; font { family: "Noto Serif Georgian"; pixelSize: 26; weight: Font.Black } }
          }
          Column {
            x: 62; anchors.verticalCenter: parent.verticalCenter; spacing: 5
            Row {
              spacing: 8
              leftPadding: 10   // the heading font's first stroke can swing left into the seal
              Text { text: Rice.t("გამარჯობა,", "Hello,"); color: "#FFFFFF"; font { family: Theme.headFor(text); pixelSize: 28 } }
              Text { anchors.baseline: parent.children[0].baseline; text: Rice.name; color: "#FFFFFF"; font { family: Theme.headFor(Rice.name); pixelSize: 26; bold: true; italic: true } }
            }
            Text { text: cc.host + " · up " + cc.uptime + (cc.gpu ? " · " + cc.gpu : ""); color: cc.grey; font { family: Theme.mono; pixelSize: 12 } }
          }
          Column {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            ClockMark { anchors.right: parent.right; date: cc.now; fmt: "24"; px: 30 }   // always 24 h here: the bar and lock screen follow the setting
            Text {
              anchors.right: parent.right; color: cc.red; font { family: Theme.labelFor(text); pixelSize: 14 }
              text: Theme.days[cc.now.getDay()] + ", " + cc.now.getDate() + " " + Theme.months[cc.now.getMonth()]
            }
          }
        }

        // tabs
        Row {
          spacing: 6
          Chip { text: Rice.t("მართვა", "Control"); on: cc.tab === "main"; onClicked: cc.tab = "main" }
          Chip { text: Rice.t("ფონი", "Wallpaper"); on: cc.tab === "wall"; onClicked: cc.tab = "wall" }
          Chip { text: Rice.t("პარამეტრები", "Settings"); on: cc.tab === "lock"; onClicked: cc.tab = "lock" }
        }

        // ================= მართვა =================
        Row {
          visible: cc.tab === "main"
          spacing: 18
          // LEFT: connectivity (wax seals: click = list drawer, hold = on/off) + sound
          Column {
            id: leftCol
            width: 309; spacing: 10
            Seal {
              id: wifiSeal
              title: "Wi-Fi"; on: cc.wifiOn; open: cc.list === "wifi"
              sub: cc.nets.find(n => n.use)?.ssid ?? (cc.wifiOn ? Rice.t("ჩართულია", "on") : Rice.t("გამორთულია", "off"))
              icon: "M2 8.5a15 15 0 0 1 20 0M5 12a10 10 0 0 1 14 0M8.5 15.5a5 5 0 0 1 7 0M12 19h.01"
              onTapped: { cc.list = "wifi"; netProc.running = true; savedProc.running = true }
              onHeld: { cc.wifiOn = !cc.wifiOn; cc.sh(["nmcli", "radio", "wifi", cc.wifiOn ? "on" : "off"]) }
              Text { visible: !cc.wifiOn || !cc.nets.length; text: !cc.wifiOn ? Rice.t("Wi-Fi გამორთულია — დააჭირე ჩასართავად", "Wi-Fi is off — press to turn on") : netProc.running ? Rice.t("ვეძებ…", "Searching…") : Rice.t("ქსელები ვერ ვიპოვე", "No networks found"); color: cc.grey; font { family: Theme.sans; pixelSize: 13 }
                padding: 10 }
              Repeater {
                model: cc.wifiOn ? cc.nets.slice(0, 4) : []
                Column {
                  id: netRow
                  required property var modelData
                  width: parent.width
                  RowBtn {
                    label: netRow.modelData.ssid
                    tag: netRow.modelData.use ? Rice.t("მიერთებულია", "connected")
                       : netRow.modelData.ent ? Rice.t("შესვლა…", "sign in…")
                       : cc.saved.includes(netRow.modelData.ssid) ? Rice.t("შენახული", "saved")
                       : netRow.modelData.sec ? Rice.t("პაროლი", "password") : Rice.t("ღია", "open")
                    tagColor: netRow.modelData.use ? cc.red : cc.grey
                    bars: Math.ceil(netRow.modelData.sig / 25)
                    onClicked: cc.pick(netRow.modelData)
                  }
                  // password field for a network you have not joined before
                  Rectangle {
                    visible: cc.pwFor === netRow.modelData.ssid
                    x: 10; width: parent.width - 20; height: visible ? 36 : 0; radius: 10
                    color: "#070607"; border.color: pwIn.activeFocus ? cc.red : "#3A2E33"
                    TextInput {
                      id: pwIn
                      anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                      verticalAlignment: TextInput.AlignVCenter
                      echoMode: TextInput.Password; color: cc.cream; font { family: Theme.sans; pixelSize: 13 }
                      onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                      Keys.onReturnPressed: if (text) cc.join(netRow.modelData.ssid, text)
                      Keys.onEnterPressed: if (text) cc.join(netRow.modelData.ssid, text)
                      Keys.onEscapePressed: cc.pwFor = ""
                      Text { visible: !parent.text; anchors.verticalCenter: parent.verticalCenter; text: Rice.t("პაროლი — Enter", "Password — Enter"); color: cc.grey; font: parent.font }
                    }
                  }
                }
              }
            }
            Seal {
              id: btSeal
              title: "Bluetooth"; on: Bluetooth.defaultAdapter?.enabled ?? false; open: cc.list === "bt"
              sub: { const d = Bluetooth.devices.values.filter(d => d.connected); return d.length ? d[0].name : (on ? Rice.t("ჩართულია", "on") : Rice.t("გამორთულია", "off")) }
              icon: "M7 7l10 10-5 4V3l5 4L7 17"
              onTapped: cc.list = "bt"
              onHeld: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
              Text { visible: !btList.count; text: btSeal.on ? Rice.t("დაწყვილებული მოწყობილობა არ არის", "No paired devices") : Rice.t("Bluetooth გამორთულია — დააჭირე ჩასართავად", "Bluetooth is off — press to turn on"); color: cc.grey; font { family: Theme.sans; pixelSize: 13 }
                padding: 10 }
              Repeater {
                id: btList
                model: Bluetooth.devices.values.filter(d => d.paired).slice(0, 4)
                RowBtn {
                  required property BluetoothDevice modelData
                  label: modelData.name
                  dot: modelData.connected ? cc.red : "#3A2E33"
                  tag: (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%  " : "") + (modelData.connected ? Rice.t("მიერთებულია", "connected") : "")
                  tagColor: cc.red
                  onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                }
              }
            }
            Seal {
              title: Rice.t("ფხიზლად", "Stay awake"); on: Rice.cfg.awake; drawer: false
              sub: on ? Rice.t("არ დაიძინებს", "won\'t sleep") : Rice.t("ჩვეულებრივ იძინებს", "sleeps as usual")
              icon: "M4 10h12v4a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5zM16 11h1.5a2.5 2.5 0 0 1 0 5H16M8 3.5v3M12 3.5v3"   // coffee cup
              hold: false
              onTapped: Rice.cfg.awake = !Rice.cfg.awake
            }

            Item { width: 1; height: 4 }
            Card {
              height: soundCol.implicitHeight + 32
              Column {
                id: soundCol
                width: parent.width; spacing: 10
                Head { text: Rice.t("ხმა", "Sound") }
                SoundGroup { sink: true; caption: Rice.t("გამომავალი", "Output") }
                SoundGroup { sink: false; caption: Rice.t("შემავალი", "Input") }
              }
            }
          }

          // RIGHT: calendar + tasks
          Column {
            width: 309; spacing: 14
            Card {
              id: calCard
              height: 290
              Column {
                width: parent.width; spacing: 6
                Item {
                  // inset so the title and arrows line up with the day numbers, not the cell edges
                  x: 9; width: parent.width - 18; height: 22
                  Head { text: Theme.months[cc.shown.getMonth()] + " " + cc.shown.getFullYear() }
                  Row {
                    anchors.right: parent.right; spacing: 6
                    Btn { text: "‹"; onClicked: cc.monthOff-- }
                    Btn { text: "›"; onClicked: cc.monthOff++ }
                  }
                }
                Item { width: 1; height: 6 }
                Grid {
                  columns: 7; columnSpacing: 2; rowSpacing: 2
                  Repeater {
                    model: Theme.daysShort
                    Text { required property string modelData; required property int index; width: (calCard.width - 36 - 12) / 7; height: 20; horizontalAlignment: Text.AlignHCenter; text: modelData; color: index > 4 ? cc.red : cc.grey; font { family: Theme.sans; pixelSize: 11; bold: true } }
                  }
                  Repeater {
                    model: 42
                    Rectangle {
                      required property int index
                      readonly property var d: new Date(cc.shown.getFullYear(), cc.shown.getMonth(), index - cc.lead + 1)
                      readonly property bool inMonth: d.getMonth() === cc.shown.getMonth()
                      readonly property bool today: d.toDateString() === cc.now.toDateString()
                      width: (calCard.width - 36 - 12) / 7; height: 30; radius: 8
                      color: today ? cc.red : "transparent"
                      Text { anchors.centerIn: parent; text: parent.d.getDate(); color: parent.today ? "#070607" : parent.inMonth ? cc.cream : "#4A4045"; font { family: Theme.sans; pixelSize: 13; bold: parent.today } }
                    }
                  }
                }
              }
            }
            Card {
              // fills whatever the left column leaves, so both columns end on the same line
              height: leftCol.height - calCard.height - 14
              Column {
                width: parent.width; spacing: 4
                Item {
                  width: parent.width; height: 30
                  Head { text: Rice.t("საქმეები", "To do") }
                  Text { anchors.right: parent.right; text: Rice.cfg.todos.filter(t => !t.done).length + " / " + Rice.cfg.todos.length; color: cc.grey; font { family: Theme.mono; pixelSize: 11 } }
                }
                Repeater {
                  model: Rice.cfg.todos
                  MouseArea {
                    id: todo
                    required property var modelData
                    required property int index
                    width: parent.width; height: 32; hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => {
                      const a = Rice.cfg.todos.slice();
                      if (m.button === Qt.RightButton) a.splice(index, 1); else a[index] = { text: modelData.text, done: !modelData.done };
                      Rice.cfg.todos = a;
                    }
                    Rectangle { anchors.fill: parent; radius: 10; color: todo.containsMouse ? "#1A1517" : "transparent" }
                    Diamond { x: 8; anchors.verticalCenter: parent.verticalCenter; size: 14; ink: todo.modelData.done ? cc.red : "#5A4E53" }
                    Text {
                      x: 32; width: parent.width - 40; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                      text: todo.modelData.text; font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold; strikeout: todo.modelData.done }
                      color: todo.modelData.done ? "#5A4E53" : cc.cream
                    }
                  }
                }
                Field {
                  id: newTodo
                  placeholder: Rice.t("ახალი საქმე… (Enter)", "New task… (Enter)")
                  onAccepted: { if (text.trim()) Rice.cfg.todos = Rice.cfg.todos.concat([{ text: text.trim(), done: false }]); text = "" }
                }
              }
            }
          }
        }

        // session strip
        Row {
          visible: cc.tab === "main"
          spacing: 12
          Repeater {
            model: [
              { l: Rice.t("ჩაკეტვა", "Lock"), i: "M6 11h12v10H6zM8 11V7a4 4 0 0 1 8 0v4", c: ["loginctl", "lock-session"] },
              { l: Rice.t("ძილი", "Sleep"), i: "M20 15A8 8 0 1 1 9 4a6 6 0 0 0 11 11z", c: ["systemctl", "suspend"] },
              { l: Rice.t("გასვლა", "Log out"), i: "M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10", c: ["hyprctl", "dispatch", Rice.hyprLua ? "hl.dsp.exit()" : "exit"] },
              { l: Rice.t("გადატვირთვა", "Restart"), i: "M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5", c: ["systemctl", "reboot"] },
              { l: Rice.t("გამორთვა", "Shut down"), i: "M12 3v9M6.3 7a8 8 0 1 0 11.4 0", c: ["systemctl", "poweroff"] }
            ]
            PowerBtn { required property var modelData; spec: modelData }
          }
        }

        // ================= პარამეტრები (lock + clock) =================
        Column {
          visible: cc.tab === "lock"
          width: parent.width; spacing: 10
          Card {
            height: 82
            Column {
              width: parent.width; spacing: 10
              Head { text: Rice.t("ჩაკეტვის ეკრანი", "Lock screen") }
              Seg {
                opts: [["random", Rice.t("შემთხვევითი", "random")], ["giorgi", Rice.t("წმ. გიორგი", "St. George")], ["flag", Rice.t("დროშა", "flag")], ["borj", Rice.t("ბორჯღალი", "Borjgali")]]
                value: Rice.cfg.lockLook; onPicked: v => Rice.cfg.lockLook = v
              }
            }
          }
          Card {
            height: 82
            Column {
              width: parent.width; spacing: 10
              Head { text: "ენა · Language" }
              Seg { opts: [["ka", "ქართული"], ["en", "English"]]; value: Rice.lang; onPicked: v => Rice.cfg.lang = v }
            }
          }
          Card {
            height: 82
            Column {
              width: parent.width; spacing: 10
              Head { text: Rice.t("საათი", "Clock") }
              Seg { opts: [["24", Rice.t("24 საათი", "24 hour")], ["ka", Rice.t("12 · დილის / საღამოს", "12 · morning / evening")], ["ampm", "12 · AM / PM"]]; value: Rice.cfg.clockFmt; onPicked: v => Rice.cfg.clockFmt = v }
            }
          }
        }

        // ================= ფონი =================
        Column {
          id: wallTab
          visible: cc.tab === "wall"
          width: parent.width; spacing: 10
          // only the settings the chosen wallpaper uses (rotating: those of Borjgali and Vazha)
          readonly property string wm: Rice.cfg.wallMode
          readonly property bool letters: wm !== "dance"
          Card {
            height: 82
            Column {
              width: parent.width; spacing: 8
              Head { text: Rice.t("ფონი", "Wallpaper") }
              Seg { opts: [["borj", Rice.t("ბორჯღალი", "Borjgali")], ["vazha", Rice.t("ვაჟა", "Vazha")]].concat(Rice.danceDir ? [["dance", Rice.t("ცეკვა", "Dance")]] : []).concat([["rot", Rice.t("მონაცვლეობით · 10 წთ", "alternate · 10 min")]]); value: Rice.cfg.wallMode; onPicked: v => Rice.cfg.wallMode = v }
            }
          }
          Card {
            height: 82
            Column {
              width: parent.width; spacing: 8
              Head { text: Rice.t("წითელი ფონი", "Red background") }
              Seg { opts: [["on", Rice.t("ჩართულია", "on")], ["off", Rice.t("გამორთულია", "off")]]; value: Rice.cfg.glow ? "on" : "off"; onPicked: v => Rice.cfg.glow = v === "on" }
            }
          }
          Card {
            visible: wallTab.letters
            height: textCol.implicitHeight + 32
            Column {
              id: textCol
              width: parent.width; spacing: 8
              Head { text: Rice.t("ტექსტი", "Text") }
              Seg { opts: [["auto", Rice.t("ავტო", "auto")], ["r", Rice.t("რუსთაველი", "Rustaveli")], ["v", Rice.t("ვაჟა", "Vazha")]]; value: Rice.cfg.wallSrc === "m" ? "auto" : Rice.cfg.wallSrc; onPicked: v => Rice.cfg.wallSrc = v }
              Text {
                width: parent.width; wrapMode: Text.Wrap; lineHeight: 1.15
                text: Rice.wallText; color: "#C9C1C4"; font { family: "Noto Serif Georgian"; pixelSize: 12 }
              }
              Row {
                spacing: 10
                Btn { text: Rice.t("ახალი სტროფი ↻", "New stanza ↻"); onClicked: Rice.stanzaSeq++ }
                Text { anchors.verticalCenter: parent.verticalCenter; text: Rice.wallInfo.startsWith("r") ? Rice.t("ვეფხისტყაოსანი · ", "The Man in the Panther's Skin, tr. Wardrop · ") + Rice.wallInfo.slice(2) : Rice.wallInfo.startsWith("v") ? Rice.t("ვაჟა-ფშაველა · ", "Vazha-Pshavela, tr. Hewitt · ") + Rice.wallInfo.slice(2) : ""; color: cc.grey; font { family: Theme.sans; pixelSize: 11 } }
              }
            }
          }
          Card {
            visible: wallTab.letters
            height: animCol.implicitHeight + 32
            Column {
              id: animCol
              width: parent.width; spacing: 10
              Head { text: Rice.t("ანიმაცია", "Animation") }
              Seg { opts: [["light", Rice.t("კითხვის შუქი", "reading light")], ["wave", Rice.t("ციმციმი", "shimmer")], ["none", Rice.t("უძრავი", "still")]]; value: Rice.cfg.anim; onPicked: v => Rice.cfg.anim = v }
              Slide { visible: Rice.cfg.anim === "light"; label: Rice.t("შუქის სიჩქარე ", "Light speed ") + Rice.cfg.speed + "%"; value: Rice.cfg.speed / 100; onMoved: v => Rice.cfg.speed = Math.round(v * 100) }
              Slide { visible: wallTab.wm !== "vazha"; label: Rice.t("ბრუნვა ", "Rotation ") + (Rice.cfg.spin ? Rice.cfg.spin + "%" : Rice.t("გაჩერებული", "stopped")); value: Rice.cfg.spin / 100; onMoved: v => Rice.cfg.spin = Math.round(v * 100) }
            }
          }
          Card {
            visible: wallTab.letters
            height: lookCol.implicitHeight + 32
            Column {
              id: lookCol
              width: parent.width; spacing: 10
              Head { text: Rice.t("შესახედაობა", "Look") }
              Slide { label: Rice.t("ფორმის ზომა ", "Shape size ") + Rice.cfg.shape + "%"; value: (Rice.cfg.shape - 40) / 90; onMoved: v => Rice.cfg.shape = Math.round(40 + v * 90) }
              Slide { label: Rice.t("ასოს ზომა ", "Letter size ") + Rice.cfg.size + "%"; value: (Rice.cfg.size - 40) / 210; onMoved: v => Rice.cfg.size = Math.round(40 + v * 210) }
              Slide { visible: wallTab.wm !== "borj"; label: Rice.t("ვაჟას შაბლონი ", "Vazha stencil ") + Rice.cfg.contrast + "%"; value: (Rice.cfg.contrast - 25) / 50; onMoved: v => Rice.cfg.contrast = Math.round(25 + v * 50) }
              Seg { opts: [["w", Rice.t("თეთრი", "white")], ["wr", Rice.t("თეთრი + წითელი", "white + red")], ["r", Rice.t("წითელი", "red")]]; value: Rice.cfg.ink; onPicked: v => Rice.cfg.ink = v }
            }
          }
        }
      }
      }

    }
  }

  // ---- helpers -----------------------------------------------------------------------------
  property int monthOff: 0
  readonly property var shown: new Date(now.getFullYear(), now.getMonth() + monthOff, 1)
  readonly property int lead: (shown.getDay() + 6) % 7
  property string list: "wifi"
  onVisibleChanged: if (!visible) { monthOff = 0; tab = "main"; soundOpen = "" }

  // ---- little components -------------------------------------------------------------------
  component Card: Rectangle {
    default property alias content: inner.data
    width: parent.width; radius: 16; color: cc.card; border.color: cc.line
    Item { id: inner; x: 18; y: 16; width: parent.width - 36; height: parent.height - 32 }
  }
  component Head: Text { color: cc.red; font { family: Theme.labelFor(text); pixelSize: 13; letterSpacing: 1.5 } }

  component Chip: MouseArea {
    property string text
    property bool on
    width: chipT.implicitWidth + 28; height: 34; hoverEnabled: true
    Rectangle { anchors.fill: parent; radius: 17; color: parent.on ? cc.red : cc.card; border.color: parent.on ? cc.red : parent.containsMouse ? cc.red : "#3A2E33" }
    Text { id: chipT; anchors.centerIn: parent; text: parent.text; color: parent.on ? "#070607" : cc.cream; font { family: Theme.sans; pixelSize: 13; weight: Font.Bold } }
  }

  component Btn: MouseArea {
    property string text
    width: btnT.implicitWidth + 16; height: 24; hoverEnabled: true
    Rectangle { anchors.fill: parent; radius: 8; color: parent.containsMouse ? "#1A1517" : "transparent"; border.color: "#3A2E33" }
    Text { id: btnT; anchors.centerIn: parent; text: parent.text; color: cc.cream; font { family: Theme.sans; pixelSize: 12; bold: true } }
  }

  component Seg: Row {
    property var opts
    property string value
    signal picked(string v)
    spacing: 4
    Repeater {
      model: parent.opts
      Chip {
        required property var modelData
        height: 30; text: modelData[1]; on: modelData[0] === parent.value
        onClicked: parent.picked(modelData[0])
      }
    }
  }

  component Tile: MouseArea {
    id: tile
    property bool on
    property string title
    property string sub
    property string icon
    width: 97; height: 80; hoverEnabled: true
    Rectangle { anchors.fill: parent; radius: 18; color: parent.on ? cc.red : cc.card; border.color: parent.on ? cc.red : parent.containsMouse ? "#5A4E53" : cc.line }
    Shape {
      x: 14; y: 12; width: 18; height: 18; preferredRendererType: Shape.CurveRenderer
      ShapePath { strokeColor: tile.on ? "#070607" : cc.cream; strokeWidth: 2.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; scale: Qt.size(0.75, 0.75); PathSvg { path: tile.icon } }
    }
    Text { x: 14; y: 36; text: parent.title; color: parent.on ? "#070607" : cc.cream; font { family: Theme.sans; pixelSize: 13; weight: Font.ExtraBold } }
    Text { x: 14; y: 55; width: parent.width - 20; elide: Text.ElideRight; textFormat: Text.PlainText; text: parent.sub; color: parent.on ? "#3A0A0F" : cc.grey; font { family: Theme.sans; pixelSize: 10 } }
  }

  // wax seal row: quick click opens its drawer, press-and-hold (0.7 s) stamps it on/off
  component Seal: Rectangle {
    id: seal
    property string title
    property string sub
    property string icon
    property bool on
    property bool open
    property bool drawer: true
    property bool hold: true        // press-and-hold ring (toggles while a tap opens the drawer); off = a tap toggles
    property real prog: 0
    default property alias rows: drawerCol.data
    signal tapped()
    signal held()
    width: parent.width; radius: 18; color: cc.card; clip: true
    border.color: open && drawer ? cc.red : cc.line
    height: 64 + (open && drawer ? drawerCol.implicitHeight + 10 : 0)
    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    MouseArea {
      id: press
      width: parent.width; height: 64; hoverEnabled: true
      property double t0
      property bool fired
      onPressed: { t0 = Date.now(); fired = false; if (seal.hold) holdAnim.restart() }
      onReleased: { holdAnim.stop(); seal.prog = 0; if (!fired && (!seal.hold || Date.now() - t0 < 300)) { seal.tapped(); if (!seal.hold) stamp.restart() } }
      onCanceled: { holdAnim.stop(); seal.prog = 0 }
      NumberAnimation {
        id: holdAnim; target: seal; property: "prog"; from: 0; to: 1; duration: 700
        onFinished: { press.fired = true; seal.prog = 0; seal.held(); stamp.restart() }
      }
      // hover tint sits inside the border (1 px inset) and, when the drawer is open, keeps a square
      // bottom so the header and the list read as one card
      Rectangle {
        x: 1; y: 1; width: parent.width - 2; height: parent.height - (seal.open && seal.drawer ? 1 : 2)
        radius: 17; bottomLeftRadius: seal.open && seal.drawer ? 0 : 17; bottomRightRadius: seal.open && seal.drawer ? 0 : 17
        color: press.containsMouse ? "#161113" : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
      }
      Item {
        id: disc
        x: 12; anchors.verticalCenter: parent.verticalCenter; width: 42; height: 42
        SequentialAnimation on scale { id: stamp; running: false; NumberAnimation { to: 0.84; duration: 110 } NumberAnimation { to: 1.07; duration: 140 } NumberAnimation { to: 1; duration: 120 } }
        Rectangle { anchors.fill: parent; radius: 21; color: seal.on ? cc.red : "#1A1517"; border.color: "#3A2E33" }
        Shape {
          anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: seal.on ? "#FFFFFF" : cc.red; strokeWidth: 3.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 21; centerY: 21; radiusX: 19; radiusY: 19; startAngle: -90; sweepAngle: seal.prog * 360 }
          }
        }
        Shape {
          x: 12; y: 12; width: 18; height: 18; preferredRendererType: Shape.CurveRenderer
          ShapePath { strokeColor: seal.on ? "#070607" : cc.cream; strokeWidth: 2.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; scale: Qt.size(0.75, 0.75); PathSvg { path: seal.icon } }
        }
      }
      Column {
        x: 66; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100
        Text { text: seal.title; color: cc.cream; font { family: Theme.sans; pixelSize: 14; weight: Font.ExtraBold } }
        Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: seal.sub + Rice.t("  ·  დააჭირე: ", "  ·  press: ") + (seal.on ? Rice.t("გამორთვა", "turn off") : Rice.t("ჩართვა", "turn on")); color: cc.grey; font { family: Theme.sans; pixelSize: 11 } }
      }
      Text { visible: seal.drawer; anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } text: seal.open ? "▴" : "▾"; color: cc.grey; font.pixelSize: 14 }
    }
    Rectangle { visible: seal.open && seal.drawer; x: 12; y: 64; width: parent.width - 24; height: 1; color: "#2A2226" }
    Column { id: drawerCol; x: 6; y: 70; width: parent.width - 12; visible: seal.open && seal.drawer }
  }

  component RowBtn: MouseArea {
    id: rb
    property string label
    property string tag
    property color tagColor: cc.grey
    property color dot: "transparent"
    property int bars: -1
    width: parent.width; height: 38; hoverEnabled: true
    Rectangle { anchors.fill: parent; radius: 12; color: parent.containsMouse ? "#1A1517" : "transparent" }
    Row {
      x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 3; visible: parent.bars >= 0
      Repeater { model: 4; Rectangle { required property int index; anchors.bottom: parent.bottom; width: 4; height: 4 + index * 3; color: index < rb.bars ? cc.red : "#3A2E33" } }
    }
    Rectangle { visible: parent.bars < 0; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: parent.dot }
    Text { x: 46; width: parent.width - 156; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; textFormat: Text.PlainText; text: parent.label; color: cc.cream; font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold } }
    Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: parent.tag; color: parent.tagColor; font { family: Theme.sans; pixelSize: 11; bold: true } }
  }

  component Slide: Item {
    property string label
    property real value
    signal moved(real v)
    width: parent.width; height: 24
    property real labelWidth: 150
    Text { width: parent.labelWidth; visible: parent.labelWidth > 0; anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: parent.label; color: cc.grey; font { family: Theme.sans; pixelSize: 12; bold: true }
      elide: Text.ElideRight }
    Item {
      id: track
      x: parent.labelWidth > 0 ? parent.labelWidth + 6 : 0; width: parent.width - x; height: parent.height
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: "#2A2226" }
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.max(0, Math.min(1, parent.parent.value)); height: 4; radius: 2; color: cc.red }
      Rectangle { anchors.verticalCenter: parent.verticalCenter; x: parent.width * Math.max(0, Math.min(1, parent.parent.value)) - 7; width: 14; height: 14; radius: 7; color: cc.cream }
      MouseArea {
        anchors.fill: parent
        function set(m) { track.parent.moved(Math.max(0, Math.min(1, m.x / width))) }
        onPressed: m => set(m)
        onPositionChanged: m => set(m)
        onWheel: w => track.parent.moved(Math.max(0, Math.min(1, track.parent.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
      }
    }
  }

  // one sound direction: device button → inline list of devices (pick = switch + close), then the level
  property string soundOpen: Quickshell.env("PHARNAVOS_SOUND") || ""
  readonly property var soundIcons: ({
    hp: "M3 18v-6a9 9 0 0 1 18 0v6M3 18a2 2 0 0 0 2 2h1v-6H5a2 2 0 0 0-2 2zM21 18a2 2 0 0 1-2 2h-1v-6h1a2 2 0 0 1 2 2z",
    spk: "M6 3h12v18H6zM9 14a3 3 0 1 0 6 0a3 3 0 1 0-6 0M12 7h.01",
    hdmi: "M3 4h18v12H3zM8 20h8M12 16v4",
    spdif: "M4 12a8 8 0 1 0 16 0a8 8 0 1 0-16 0M10 12a2 2 0 1 0 4 0a2 2 0 1 0-4 0",
    mic: "M9 3h6v10H9zM5 11a7 7 0 0 0 14 0M12 18v3",
    line: "M4 12h6M14 12h6M10 9v6M14 9v6"
  })
  function soundKind(n, sink) {
    const d = (n?.description || n?.nickname || n?.name || "").toLowerCase();
    if (!sink) return d.includes("line") ? "line" : "mic";
    return d.includes("hdmi") ? "hdmi" : d.includes("s/pdif") || d.includes("spdif") || d.includes("iec958") ? "spdif" : d.includes("headphone") ? "hp" : "spk";
  }
  function soundName(n, sink) {
    return { hp: Rice.t("ყურსასმენი", "Headphones"), spk: Rice.t("დინამიკები", "Speakers"), hdmi: Rice.t("მონიტორი", "Monitor"), spdif: Rice.t("ოპტიკური", "Optical"), mic: Rice.t("მიკროფონი", "Microphone"), line: Rice.t("ხაზი", "Line") }[soundKind(n, sink)];
  }
  function soundDesc(n) {
    const d = (n?.description || n?.nickname || n?.name || "—").replace(/^USB Audio\s*/, "USB · ");
    return /hdmi/i.test(d) ? "HDMI · GPU" : d;
  }

  component SoundGroup: Column {
    id: sg
    property bool sink
    property string caption
    readonly property string key: sink ? "out" : "in"
    readonly property bool open: cc.soundOpen === key
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && n.isSink === sink)
    readonly property PwNode cur: sink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource
    width: parent.width; spacing: 0
    PwObjectTracker { objects: sg.nodes }

    // device button
    MouseArea {
      id: devBtn
      width: parent.width; height: 54; hoverEnabled: true
      onClicked: cc.soundOpen = sg.open ? "" : sg.key
      Rectangle {
        anchors.fill: parent; color: devBtn.containsMouse && !sg.open ? "#120E10" : "#070607"
        radius: 12; bottomLeftRadius: sg.open ? 0 : 12; bottomRightRadius: sg.open ? 0 : 12
        border.color: sg.open ? cc.red : devBtn.containsMouse ? "#5A4E53" : cc.line
      }
      Shape {
        x: 11; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; preferredRendererType: Shape.CurveRenderer
        ShapePath { strokeColor: cc.red; strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; scale: Qt.size(20 / 24, 20 / 24); PathSvg { path: cc.soundIcons[cc.soundKind(sg.cur, sg.sink)] } }
      }
      Column {
        x: 40; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 86
        spacing: 1
        Text { width: parent.width; elide: Text.ElideRight; text: cc.soundName(sg.cur, sg.sink); color: cc.cream; font { family: Theme.sans; pixelSize: 14; weight: Font.ExtraBold } }
        Text { width: parent.width; elide: Text.ElideRight; text: cc.soundDesc(sg.cur).replace(/^USB · /, ""); color: "#A79DA2"; font { family: Theme.sans; pixelSize: 12 } }
      }
      Text { anchors { right: parent.right; rightMargin: 30; verticalCenter: parent.verticalCenter } text: sg.nodes.length; color: cc.grey; font { family: Theme.sans; pixelSize: 12; bold: true } }
      Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: "▾"; rotation: sg.open ? 180 : 0; color: cc.grey; font.pixelSize: 13; Behavior on rotation { NumberAnimation { duration: 200 } } }
    }

    // device list
    Rectangle {
      visible: sg.open
      width: parent.width; height: devList.implicitHeight + 8
      color: "#070607"; border.color: cc.red; radius: 12; topLeftRadius: 0; topRightRadius: 0
      Rectangle { x: 1; width: parent.width - 2; height: 1; color: "#070607" }
      Column {
        id: devList
        x: 4; y: 4; width: parent.width - 8
        Repeater {
          model: sg.nodes
          MouseArea {
            id: opt
            required property PwNode modelData
            readonly property bool on: modelData === sg.cur
            width: parent.width; height: 46; hoverEnabled: true
            onClicked: { if (sg.sink) Pipewire.preferredDefaultAudioSink = modelData; else Pipewire.preferredDefaultAudioSource = modelData; cc.soundOpen = "" }
            Rectangle { anchors.fill: parent; radius: 9; color: opt.containsMouse ? "#1A1517" : "transparent" }
            Diamond { x: 10; anchors.verticalCenter: parent.verticalCenter; size: 12; ink: opt.on ? cc.red : "#3A2E33" }
            Shape {
              x: 30; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; preferredRendererType: Shape.CurveRenderer
              ShapePath { strokeColor: opt.on ? "#FFFFFF" : cc.cream; strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; scale: Qt.size(16 / 24, 16 / 24); PathSvg { path: cc.soundIcons[cc.soundKind(opt.modelData, sg.sink)] } }
            }
            Column {
              x: 56; width: parent.width - 108; anchors.verticalCenter: parent.verticalCenter
              Text { width: parent.width; elide: Text.ElideRight; text: cc.soundName(opt.modelData, sg.sink); color: opt.on ? "#FFFFFF" : cc.cream; font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold } }
              Text { width: parent.width; elide: Text.ElideRight; text: cc.soundDesc(opt.modelData); color: "#A79DA2"; font { family: Theme.sans; pixelSize: 11 } }
            }
            Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: Math.round((opt.modelData.audio?.volume ?? 0) * 100) + "%"; color: cc.grey; font { family: Theme.sans; pixelSize: 11; bold: true } }
          }
        }
      }
    }

    // level: mute + slider + number
    Item {
      width: parent.width; height: 40
      MouseArea {
        id: muteBtn
        y: 6; width: 32; height: 32; hoverEnabled: true
        readonly property bool muted: sg.cur?.audio.muted ?? false
        onClicked: if (sg.cur) sg.cur.audio.muted = !sg.cur.audio.muted
        Rectangle { anchors.fill: parent; radius: 16; color: muteBtn.muted ? "#2A2226" : "transparent"; border.color: muteBtn.containsMouse ? cc.red : cc.line }
        Shape {
          anchors.centerIn: parent; width: 15; height: 15; preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: muteBtn.muted ? "#5A4E53" : "#C9C1C4"; strokeWidth: 2.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; scale: Qt.size(15 / 24, 15 / 24)
            PathSvg { path: sg.sink ? (muteBtn.muted ? "M4 9v6h4l5 4V5L8 9zM17 9l4 6M21 9l-4 6" : "M4 9v6h4l5 4V5L8 9zM16 9a4 4 0 0 1 0 6") : (muteBtn.muted ? "M9 3h6v10H9zM5 11a7 7 0 0 0 14 0M12 18v3M3 3l18 18" : "M9 3h6v10H9zM5 11a7 7 0 0 0 14 0M12 18v3") }
          }
        }
      }
      Slide {
        x: 42; y: 10; width: parent.width - 42 - 40; label: ""; labelWidth: 0
        value: sg.cur?.audio.volume ?? 0
        onMoved: v => { if (sg.cur) sg.cur.audio.volume = v }
      }
      Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: 2 } text: Math.round((sg.cur?.audio.volume ?? 0) * 100); color: "#C9C1C4"; font { family: Theme.sans; pixelSize: 12; bold: true } }
    }
  }

  component Field: Rectangle {
    property alias text: input.text
    property string placeholder
    signal accepted()
    width: parent.width; height: 36; radius: 12; color: "transparent"; border.color: input.activeFocus ? cc.red : "#3A2E33"
    TextInput {
      id: input
      x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; clip: true
      color: cc.cream; selectionColor: cc.red; font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold }
      onAccepted: parent.accepted()
      Keys.onEscapePressed: Rice.ccOpen = false
      Text { visible: !parent.text && !parent.activeFocus; text: parent.parent.placeholder; color: "#5A4E53"; font: parent.font }
    }
  }

  component Diamond: Item {
    property real size
    property color ink
    width: size; height: size
    Repeater {
      model: [1, 3, 5, 3, 1]
      Rectangle { required property int index; required property int modelData; readonly property real u: parent.size / 5; x: (5 - modelData) / 2 * u; y: index * u; width: modelData * u; height: u; color: parent.ink }
    }
  }

  // the dangerous ones need a 1 s hold
  component PowerBtn: MouseArea {
    id: pb
    property var spec
    // five equal buttons spanning the panel: first and last sit on the content edges
    width: (body.width - 4 * 12) / 5; height: 64; hoverEnabled: true
    // one click acts (your call; the old 1 s hold guard on reboot / shutdown / logout is gone)
    onClicked: { Rice.ccOpen = false; cc.sh(spec.c) }
    Rectangle {
      anchors.fill: parent; radius: 16; color: cc.card; border.color: parent.containsMouse ? cc.red : cc.line; clip: true
    }
    Shape {
      anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 20; height: 20; preferredRendererType: Shape.CurveRenderer
      ShapePath { strokeColor: cc.cream; strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; scale: Qt.size(20 / 24, 20 / 24); PathSvg { path: pb.spec.i } }
    }
    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 38; text: pb.spec.l; color: cc.cream; font { family: Theme.sans; pixelSize: 12; bold: true } }
  }
}
