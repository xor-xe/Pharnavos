// Launcher (LauncherPro): embroidered list + side pane for the selected app. Plain text searches apps
// (Georgian keyboard input matches Latin names); prefixes switch mode:
//   = calc   > run   ? ask (local ollama)   @ windows   # translate KA⇄EN (local)   ! web
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
  id: lw
  required property var bar
  screen: bar.screen
  WlrLayershell.namespace: "pharnavos-launcher"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: Rice.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  property bool mapped: false
  visible: mapped

  readonly property color red: Theme.red
  readonly property color cream: Theme.cream
  readonly property color grey: "#8C8186"
  readonly property color line: "#3A2E33"

  // ---- open / close ------------------------------------------------------------------------
  property real shown: 0     // 0 → 1 fade + drop
  property real sewn: 0
  NumberAnimation { id: inA; target: lw; property: "shown"; to: 1; duration: 220; easing.type: Easing.OutCubic }
  NumberAnimation { id: sewA; target: lw; property: "sewn"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutQuad }
  NumberAnimation { id: outA; target: lw; property: "shown"; to: 0; duration: 150; onFinished: lw.mapped = false }
  Connections {
    target: Rice
    function onLauncherOpenChanged() {
      if (Rice.launcherOpen) {
        query.text = Rice.launcherText; Rice.launcherText = ""; lw.sel = 0; lw.aiText = "";
        lw.mapped = true; outA.stop(); inA.start(); sewA.restart();
        Hyprland.refreshToplevels();
        query.forceActiveFocus();
      } else { aiProc.running = false; inA.stop(); outA.start(); }
    }
  }
  function close() { Rice.launcherOpen = false }

  // ---- data --------------------------------------------------------------------------------
  readonly property string q: query.text
  readonly property string prefixes: Rice.ai ? "=>?@#!" : "=>@!"      // ? and # only with AI on
  readonly property string pfx: prefixes.includes(q.charAt(0)) && q.length ? q.charAt(0) : ""
  readonly property string body: pfx ? q.slice(1).trim() : q.trim()
  readonly property var modes: ({
    "": [Rice.t("აპები", "apps"), "apps", Theme.red], "=": [Rice.t("გამოთვლა", "calc"), "calc", Theme.cream], ">": [Rice.t("ბრძანება", "run"), "run", "#FFFFFF"],
    "?": [Rice.t("ჰკითხე", "ask"), "ask", "#2FA5A0"], "@": [Rice.t("ფანჯრები", "windows"), "windows", Theme.red], "#": [Rice.t("თარგმნა", "translate"), "translate", "#A880F0"], "!": [Rice.t("ვებში", "web"), "web", "#3FA9E0"]
  })
  readonly property color modeColor: modes[pfx][2]

  readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
  function uses(e) { return Rice.cfg.launches[e.id] || 0 }
  // ranking: real launch counts
  function rank(e) { return uses(e) }

  // Georgian keyboard → Latin, so ფაიერფოქს / სტეამ still find apps
  readonly property var ka: ({ "ა": "a", "ბ": "b", "გ": "g", "დ": "d", "ე": "e", "ვ": "v", "ზ": "z", "თ": "t", "ი": "i", "კ": "k", "ლ": "l", "მ": "m", "ნ": "n", "ო": "o", "პ": "p", "ჟ": "zh", "რ": "r", "ს": "s", "ტ": "t", "უ": "u", "ფ": "f", "ქ": "k", "ღ": "gh", "ყ": "q", "შ": "sh", "ჩ": "ch", "ც": "ts", "ძ": "dz", "წ": "ts", "ჭ": "ch", "ხ": "kh", "ჯ": "j", "ჰ": "h" })
  function translit(s) { return s.toLowerCase().replace(/ქს/g, "x").split("").map(c => ka[c] ?? c).join("").replace(/ /g, "") }
  // in-order fuzzy match; c/k and f/ph count as the same; returns matched indices in `name`
  function fuzzy(q, name) {
    const n = name.toLowerCase(), hits = [];
    let qi = 0;
    for (let i = 0; i < n.length && qi < q.length; i++) {
      const a = n[i], b = q[qi];
      if (a === b || ("ck".includes(a) && "ck".includes(b))) { hits.push(i); qi++; }
      else if (b === "f" && n.substr(i, 2) === "ph") { hits.push(i, i + 1); qi++; i++; }
    }
    return qi === q.length ? hits : null;
  }

  // consonant skeleton for phonetic Georgian spellings: ფაიერფოქს → frfks ~ firefox → frfks
  function skel(s) { return s.toLowerCase().replace(/ph/g, "f").replace(/x/g, "ks").replace(/c/g, "k").replace(/w/g, "v").replace(/[aeiouy\s\-_.]/g, "") }
  function inOrder(q, n) { let i = 0; for (const c of n) if (c === q[i]) i++; return i === q.length }

  readonly property var appRows: {
    if (pfx) return [];
    const t = translit(body);
    if (!t) return apps.slice().sort((a, b) => rank(b) - rank(a) || a.name.localeCompare(b.name)).slice(0, 8).map(e => ({ e, hits: [] }));
    return apps.map(e => {
      let hits = fuzzy(t, e.name), alt = 0;
      if (!hits && (e.genericName && fuzzy(t, e.genericName) || e.keywords.some(k => fuzzy(t, k)))) { hits = []; alt = 1 }
      if (!hits && skel(t).length >= 2 && inOrder(skel(t), skel(e.name))) { hits = []; alt = skel(e.name).startsWith(skel(t)) ? 0 : 1 }
      if (!hits) return null;
      const lead = e.name.toLowerCase().replace(/ph/g, "f").replace(/c/g, "k").startsWith(t.replace(/c/g, "k")) ? 1000 : 0;
      return { e, hits, score: lead + rank(e) * 5 - (hits.length ? (hits[hits.length - 1] - hits[0]) * 3 : 40) - alt * 60 };
    }).filter(x => x).sort((a, b) => b.score - a.score).slice(0, 8);
  }
  readonly property var winRows: pfx !== "@" ? [] : Hyprland.toplevels.values
    .map(t => ({ t, cls: t.lastIpcObject?.class ?? "", title: t.title ?? "", ws: t.workspace?.name ?? "" }))
    .filter(w => !body || translit(w.cls + w.title).includes(translit(body)) || (w.cls + w.title).toLowerCase().includes(body.toLowerCase()))
  readonly property int count: pfx === "@" ? winRows.length : appRows.length
  property int sel: 0
  readonly property int selI: count ? Math.min(sel, count - 1) : 0
  // first visible row when there are more than 8: moves only as far as needed to keep the selection in view
  property int first: 0
  onSelIChanged: first = Math.max(0, Math.min(Math.max(Math.min(first, selI), selI - 7), count - 8))
  onCountChanged: first = Math.max(0, Math.min(first, count - 8))
  readonly property var pick: !pfx && appRows.length ? appRows[selI].e : null
  function windowsOf(e) {
    const k = (e.startupClass || e.id || "").toLowerCase();
    return Hyprland.toplevels.values.filter(t => { const c = (t.lastIpcObject?.class ?? "").toLowerCase(); return c && (c === k || k.includes(c) || c.includes(k)); });
  }
  readonly property var pins: apps.slice().sort((a, b) => rank(b) - rank(a) || a.name.localeCompare(b.name)).slice(0, 8)

  // ---- actions -----------------------------------------------------------------------------
  function bump(e) { const l = Object.assign({}, Rice.cfg.launches); l[e.id] = (l[e.id] || 0) + 1; Rice.cfg.launches = l }
  // Terminal=true apps (kew, htop…): Quickshell's execute() ignores that flag, so open them in the terminal
  function run(e) { if (e.runInTerminal) Quickshell.execDetached([Rice.terminal, "-e"].concat(e.command)); else e.execute() }
  function launch(e) { bump(e); run(e); close() }
  function launchOn(e, ws) {
    bump(e);
    const cmd = (e.runInTerminal ? [Rice.terminal, "-e"].concat(e.command) : e.command).join(" ");
    Rice.dispatch("exec [workspace " + ws + "] " + cmd, "hl.dsp.exec_cmd(" + Rice.luaStr(cmd) + ", { workspace = \"" + ws + "\" })");
    close();
  }
  function focusWin(t) { Rice.dispatch("focuswindow address:0x" + t.address, "hl.dsp.focus({ window = \"address:0x" + t.address + "\" })"); close() }
  function web(text) { Qt.openUrlExternally("https://duckduckgo.com/?q=" + encodeURIComponent(text)); close() }
  function shq(s) { return "'" + s.replace(/'/g, "'\\''") + "'" }

  readonly property string calc: {
    if (pfx !== "=" || !body) return "";
    const ex = body.replace(/,/g, ".").replace(/\^/g, "**").replace(/×/g, "*").replace(/÷/g, "/");
    if (!/^[0-9+\-*/().% ]+$/.test(ex)) return "…";
    try { const v = Function('"use strict"; return (' + ex + ")")(); return isFinite(v) ? String(+v.toFixed(8)) : "…" } catch (e) { return "…" }
  }

  property string aiText: ""
  Process {
    id: aiProc
    // ollama streams JSON lines; OpenAI-style servers stream "data: {…}" lines
    stdout: SplitParser {
      onRead: l => {
        const s = l.startsWith("data: ") ? l.slice(6) : l;
        if (!s || s === "[DONE]") return;
        try { const j = JSON.parse(s); lw.aiText += j.response ?? j.choices?.[0]?.delta?.content ?? "" } catch (e) {}
      }
    }
  }
  // ? and # ask the model from programs.pharnavos.ai (ollama, or any OpenAI-compatible server)
  function ask(model, prompt) {
    aiText = ""; aiProc.running = false;
    if (!model) { aiText = Rice.t("მოდელი არ არის მითითებული (programs.pharnavos.ai.model)", "No model set (programs.pharnavos.ai.model)"); return }
    if (Rice.aiApi === "openai") {
      const req = JSON.stringify({ model, messages: [{ role: "user", content: prompt }], stream: true });
      // the key is read from its file only now, so it never sits in the Nix store or the environment
      aiProc.command = ["sh", "-c", 'k=""; [ -n "$1" ] && k="Authorization: Bearer $(cat "$1")"; exec curl -sN "$2/chat/completions" -H "Content-Type: application/json" ${k:+-H "$k"} -d "$3"',
                        "_", Rice.aiKeyFile, Rice.aiUrl, req];
    } else {
      aiProc.command = ["curl", "-sN", Rice.aiUrl + "/api/generate", "-d", JSON.stringify({ model, prompt, stream: true, think: false })];
    }
    aiProc.running = true;
  }
  onQChanged: { sel = 0; if ("?#".includes(pfx) || aiText) { aiProc.running = false; aiText = "" } }

  function enter() {
    if (!pfx) { if (pick) launch(pick); else if (body) web(body); return }
    if (pfx === "@") { if (winRows.length) focusWin(winRows[selI].t); return }
    if (!body) return;
    if (pfx === "=") { if (calc && calc !== "…") { Quickshell.clipboardText = calc; close() } return }
    if (pfx === ">") {
      const cmd = Rice.terminal + " -e sh -c " + shq(body + Rice.t("; echo; read -r -p '↵ დახურვა' _", "; echo; read -r -p '↵ close' _"));
      Rice.dispatch("exec [float; size 1100 650] " + cmd, "hl.dsp.exec_cmd(" + Rice.luaStr(cmd) + ", { float = true, size = \"1100 650\" })");
      close(); return;
    }
    if (pfx === "!") { web(body); return }
    if (pfx === "?") { ask(Rice.askModel, body); return }
    if (pfx === "#") {
      const toEn = /[ა-ჿ]/.test(body);
      ask(Rice.translateModel, "Translate the following " + (toEn ? "Georgian text to English" : "text to Georgian") + ". Reply with the translation only.\n\n" + body);
    }
  }

  // ---- UI ----------------------------------------------------------------------------------
  Rectangle { anchors.fill: parent; color: Qt.rgba(6 / 255, 5 / 255, 6 / 255, 0.45 * lw.shown) }
  MouseArea { anchors.fill: parent; onClicked: lw.close() }

  Rectangle {
    id: panel
    x: (parent.width - width) / 2; y: 104 - 24 * (1 - lw.shown)
    width: 960; height: col.implicitHeight + 40
    opacity: lw.shown
    color: "#0B090A"; radius: 6
    MouseArea { anchors.fill: parent }   // eat clicks so they don't close

    Stitch { anchors.fill: parent; inset: 6; stroke: 3; thread: lw.modeColor; to: lw.sewn }

    Column {
      id: col
      x: 24; y: 20; width: parent.width - 48; spacing: 10

      // search
      Item {
        width: parent.width; height: 54
        Shape {
          x: 0; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; preferredRendererType: Shape.CurveRenderer
          ShapePath { strokeColor: lw.red; strokeWidth: 2.4; fillColor: "transparent"; capStyle: ShapePath.RoundCap; scale: Qt.size(20 / 24, 20 / 24); PathSvg { path: "M4 11a7 7 0 1 0 14 0a7 7 0 1 0-14 0M20 20l-4-4" } }
        }
        TextInput {
          id: query
          x: 32; width: parent.width - 32 - badge.width - 10; anchors.verticalCenter: parent.verticalCenter
          color: lw.cream; selectionColor: lw.red; clip: true
          font { family: Theme.sans; pixelSize: 20; bold: true }
          Text {
            visible: !parent.text
            // only the prefixes that exist (? and # need programs.pharnavos.ai)
            text: Rice.t("რას ეძებ?  ·  ", "Search…  ·  ") + lw.prefixes.split("").map(k => k + " " + ({ "=": Rice.t("გამოთვლა", "calc"), ">": Rice.t("ბრძანება", "run"), "?": Rice.t("კითხვა", "ask"), "@": Rice.t("ფანჯრები", "windows"), "#": Rice.t("თარგმნა", "translate"), "!": Rice.t("ვები", "web") })[k]).join("  ")
            color: "#5A5055"; font: parent.font; elide: Text.ElideRight; width: parent.width
          }
          Keys.onPressed: ev => {
            if (ev.key === Qt.Key_Down) { lw.sel = (lw.selI + 1) % Math.max(1, lw.count); ev.accepted = true }
            else if (ev.key === Qt.Key_Up) { lw.sel = (lw.selI - 1 + lw.count) % Math.max(1, lw.count); ev.accepted = true }
            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { lw.enter(); ev.accepted = true }
            else if (ev.key === Qt.Key_Escape) { if (text) text = ""; else lw.close(); ev.accepted = true }
            else if ((ev.modifiers & Qt.AltModifier) && ev.key >= Qt.Key_1 && ev.key <= Qt.Key_8) { const e = lw.pins[ev.key - Qt.Key_1]; if (e) lw.launch(e); ev.accepted = true }
          }
        }
        Rectangle {
          id: badge
          anchors { right: parent.right; verticalCenter: parent.verticalCenter }
          width: badgeT.implicitWidth + 20; height: 24; radius: 4
          color: lw.pfx ? lw.modeColor : "transparent"; border.color: lw.pfx ? lw.modeColor : "#2E272A"
          Text { id: badgeT; anchors.centerIn: parent; text: lw.modes[lw.pfx][1]; color: lw.pfx ? "#070607" : "#5A5055"; font { family: Theme.mono; pixelSize: 11; bold: true } }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: lw.line }
      }

      // pinned favourites
      Row {
        visible: !lw.q
        spacing: 8
        Repeater {
          model: lw.pins
          MouseArea {
            id: pin
            required property var modelData
            required property int index
            width: 64; height: 64; hoverEnabled: true
            onClicked: lw.launch(modelData)
            Rectangle { anchors.fill: parent; radius: 4; color: "#0B090A"; border.color: pin.containsMouse ? lw.red : "#2E272A" }
            Image { x: 14; y: 6; width: 36; height: 36; sourceSize: Qt.size(72, 72); mipmap: true; source: Theme.iconFor(pin.modelData.icon) }
            Text { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 5 } width: 58; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: pin.modelData.name; color: "#C9C1C4"; font { family: Theme.sans; pixelSize: 10; bold: true } }
            Text { x: 52; y: 3; text: pin.index + 1; color: "#5A5055"; font { family: Theme.mono; pixelSize: 9; bold: true } }
          }
        }
      }

      Row {
        spacing: 18
        // LEFT: results
        Column {
          id: listCol
          width: 540; spacing: 6
          Text {
            text: lw.pfx === "@" ? Rice.t("ფანჯრები — OPEN WINDOWS", "OPEN WINDOWS") : lw.pfx ? Rice.t("შედეგი — RESULT", "RESULT") : lw.body ? Rice.t("აპები — APPS", "APPS") : Rice.t("ხშირად — FREQUENT", "FREQUENT")
            color: lw.grey; font { family: Theme.sans; pixelSize: 10; weight: Font.Black; letterSpacing: 1.6 }
          }

          // special result card for the prefix modes
          Rectangle {
            visible: lw.pfx !== "" && lw.pfx !== "@"
            width: parent.width; height: visible ? special.implicitHeight + 28 : 0; radius: 4; color: "transparent"
            Stitch { anchors.fill: parent; inset: 1; stroke: 2; thread: lw.modeColor }
            Column {
              id: special
              x: 14; y: 14; width: parent.width - 28; spacing: 4
              Text { text: lw.modes[lw.pfx][0]; color: lw.modeColor; font { family: Theme.sans; pixelSize: 11; weight: Font.Black; letterSpacing: 1.4 } }
              Text {
                width: parent.width; wrapMode: Text.WrapAnywhere; maximumLineCount: 4; elide: Text.ElideRight; color: lw.cream; font { family: lw.pfx === "=" || lw.pfx === ">" ? Theme.mono : Theme.sans; pixelSize: 22; bold: true }
                text: lw.pfx === "=" ? "= " + (lw.calc || "…") : lw.pfx === ">" ? "$ " + (lw.body || "…") : (lw.body || "…")
              }
              Text {
                visible: lw.aiText !== "" || aiProc.running
                width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 12; elide: Text.ElideRight
                text: lw.aiText || Rice.t("ფიქრობს…", "Thinking…"); color: "#C9C1C4"; font { family: Theme.sans; pixelSize: 14 }
                  lineHeight: 1.3
              }
              Text {
                color: lw.grey; font { family: Theme.mono; pixelSize: 11 }
                text: ({ "=": Rice.t("Enter აკოპირებს პასუხს", "Enter copies the answer"), ">": Rice.t("Enter უშვებს მცურავ ტერმინალში", "Enter runs it in a floating terminal"), "?": Rice.aiLocal ? Rice.t("Enter ეკითხება ლოკალურ მოდელს — არაფერი გადის კომპიუტერიდან", "Enter asks the local model — nothing leaves your computer") : Rice.t("Enter ეკითხება მოდელს (", "Enter asks the model (") + Rice.aiUrl + ")", "#": Rice.t("Enter თარგმნის (ქართ ⇄ ინგლ)", "Enter translates (ka ⇄ en)") + (Rice.aiLocal ? Rice.t(" ლოკალურად", " locally") : ""), "!": Rice.t("Enter ხსნის ბრაუზერში", "Enter opens it in the browser") })[lw.pfx] ?? ""
              }
            }
          }

          // rows (apps or windows) with marching-stitch selection
          Item {
            // fixed height in list modes so the panel never resizes while you move through results
            width: parent.width; height: lw.pfx === "" || lw.pfx === "@" ? 8 * 46 : rows.implicitHeight
            // more than 8 windows: the list scrolls with the selection (wheel too) instead of overflowing
            clip: true
            WheelHandler { onWheel: e => lw.sel = Math.max(0, Math.min(lw.count - 1, lw.selI + (e.angleDelta.y < 0 ? 1 : -1))) }
            Column {
              id: rows
              y: -lw.first * 46
              width: parent.width; spacing: 2
              Repeater {
                model: lw.pfx === "@" ? lw.winRows : lw.appRows
                MouseArea {
                  id: row
                  required property var modelData
                  required property int index
                  readonly property bool isWin: lw.pfx === "@"
                  readonly property var wins: isWin ? [] : lw.windowsOf(modelData.e)
                  width: parent.width; height: 44; hoverEnabled: true
                  // selection is sewn onto the row itself (no highlight travelling over other rows)
                  readonly property bool on: index === lw.selI
                  Rectangle { anchors.fill: parent; radius: 4; color: Theme.red; opacity: row.on ? 0.07 : 0; Behavior on opacity { NumberAnimation { duration: 160 } } }
                  Stitch {
                    anchors.fill: parent; inset: 1; stroke: 2; thread: lw.red
                    // whole border at once, faded: when flicking through rows a sew-on never finishes
                    opacity: row.on ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 110 } }
                    NumberAnimation on crawl { from: 0; to: 2.5; duration: 900; loops: Animation.Infinite; running: row.on && lw.mapped }
                  }
                  // only real mouse movement selects: rows sliding under a still cursor while typing don't
                  onPositionChanged: if (lw.sel !== index) lw.sel = index
                  onClicked: isWin ? lw.focusWin(modelData.t) : lw.launch(modelData.e)
                  Image {
                    x: 10; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; sourceSize: Qt.size(64, 64); mipmap: true
                    source: Theme.iconFor(row.isWin ? row.modelData.cls.toLowerCase() : row.modelData.e.icon)
                  }
                  Text {
                    x: 54; width: parent.width - 54 - 130; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                    textFormat: Text.StyledText; color: lw.cream; font { family: Theme.sans; pixelSize: 15; bold: true }
                    text: {
                      if (row.isWin) return row.modelData.title.replace(/&/g, "&amp;").replace(/</g, "&lt;");
                      const n = row.modelData.e.name, h = row.modelData.hits;
                      let out = "";
                      for (let i = 0; i < n.length; i++) { const c = n[i].replace("&", "&amp;").replace("<", "&lt;"); out += h.includes(i) ? "<font color=\"" + lw.red + "\">" + c + "</font>" : c }
                      return out;
                    }
                  }
                  Row {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 10
                    Row {
                      visible: row.wins.length > 0; spacing: 5; anchors.verticalCenter: parent.verticalCenter
                      Rectangle { width: 7; height: 7; radius: 4; color: lw.red; anchors.verticalCenter: parent.verticalCenter }
                      Text { text: row.wins.length; color: lw.red; font { family: Theme.mono; pixelSize: 11; bold: true } }
                    }
                    Text {
                      width: 70; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                      text: row.isWin ? Rice.t("სამუშაო ", "workspace ") + row.modelData.ws : (row.modelData.e.categories.find(c => !["GTK", "Qt", "KDE", "GNOME", "Application"].includes(c)) ?? "").toLowerCase()
                      color: lw.grey; font { family: Theme.mono; pixelSize: 11 }
                    }
                  }
                }
              }
            }
          }
          Text {
            visible: !lw.pfx && lw.body && !lw.appRows.length
            text: Rice.t("ვერაფერი ვიპოვე — Enter ეძებს ვებში", "Nothing found — Enter searches the web"); color: lw.grey; padding: 12; font { family: Theme.sans; pixelSize: 13; bold: true }
          }
        }

        // RIGHT: the selected app, opened up
        Item {
          width: col.width - listCol.width - 18; height: listCol.height
          clip: true
          Rectangle { width: 2; height: parent.height; color: lw.line }
          Column {
            id: pane
            visible: lw.pick !== null
            x: 20; width: parent.width - 20; spacing: 6
            Row {
              spacing: 12
              Item {
                width: 76; height: 76
                Image { anchors.centerIn: parent; width: 64; height: 64; sourceSize: Qt.size(128, 128); mipmap: true; source: lw.pick ? Theme.iconFor(lw.pick.icon) : "" }
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter; width: pane.width - 90
                Text { width: parent.width; elide: Text.ElideRight; text: lw.pick?.name ?? ""; color: "#FFFFFF"; font { family: Theme.sans; pixelSize: 24; weight: Font.Black } }
                Text { width: parent.width; elide: Text.ElideRight; text: [lw.pick?.genericName, lw.pick ? lw.uses(lw.pick) + Rice.t("× გაშვებული", "× launched") : ""].filter(s => s).join(" · "); color: lw.grey; font { family: Theme.mono; pixelSize: 11 } }
              }
            }

            Text { visible: winList.count > 0; topPadding: 10; text: Rice.t("ღიაა — JUMP TO WINDOW", "JUMP TO WINDOW"); color: lw.red; font { family: Theme.sans; pixelSize: 10; weight: Font.Black; letterSpacing: 1.6 } }
            Repeater {
              id: winList
              model: lw.pick ? lw.windowsOf(lw.pick).slice(0, 3) : []
              PaneBtn { required property var modelData; label: modelData.title; tag: modelData.workspace?.name ?? ""; onClicked: lw.focusWin(modelData) }
            }

            Text { topPadding: 10; text: Rice.t("მოქმედებები — ACTIONS", "ACTIONS"); color: lw.grey; font { family: Theme.sans; pixelSize: 10; weight: Font.Black; letterSpacing: 1.6 } }
            PaneBtn { label: Rice.t("გაშვება", "Launch"); tag: "↵"; onClicked: lw.launch(lw.pick) }
            Repeater {
              model: lw.pick ? lw.pick.actions.slice(0, 4) : []
              PaneBtn { required property var modelData; label: modelData.name; onClicked: { lw.bump(lw.pick); lw.run(modelData); lw.close() } }
            }

            Text { topPadding: 10; text: Rice.t("გაუშვი სადაც — OPEN ON", "OPEN ON"); color: lw.grey; font { family: Theme.sans; pixelSize: 10; weight: Font.Black; letterSpacing: 1.6 } }
            Row {
              spacing: 6
              Repeater {
                model: Rice.lang === "en" ? ["1", "2", "3", "4", "5", "6", "7", "8", "9"] : ["ა", "ბ", "გ", "დ", "ე", "ვ", "ზ", "თ", "ი"]
                MouseArea {
                  id: wsBtn
                  required property string modelData
                  required property int index
                  width: 30; height: 30; hoverEnabled: true
                  onClicked: lw.launchOn(lw.pick, index + 1)
                  Rectangle { anchors.fill: parent; radius: 4; color: "transparent"; border.color: wsBtn.containsMouse ? lw.red : lw.line }
                  Text { anchors.centerIn: parent; text: wsBtn.modelData; color: "#C9C1C4"; font { family: Theme.sans; pixelSize: 13; weight: Font.ExtraBold } }
                }
              }
            }
          }
        }
      }

      // mode chips
      Rectangle { width: parent.width; height: 2; color: lw.line }
      Item {
        width: parent.width; height: 30
        Row {
          spacing: 6
          Repeater {
            model: lw.prefixes.split("")
            MouseArea {
              id: chip
              required property string modelData
              width: chipRow.implicitWidth + 20; height: 28; hoverEnabled: true
              onClicked: { query.text = modelData; query.forceActiveFocus() }
              Rectangle { anchors.fill: parent; radius: 4; color: "transparent"; border.color: chip.containsMouse ? lw.red : lw.line }
              Row {
                id: chipRow; anchors.centerIn: parent; spacing: 6
                Text { text: chip.modelData; color: lw.red; font { family: Theme.mono; pixelSize: 11; bold: true } }
                Text { text: lw.modes[chip.modelData][0]; color: "#C9C1C4"; font { family: Theme.sans; pixelSize: 11; bold: true } }
              }
            }
          }
        }
        Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: "↑↓ ↵ · Alt+1…8 · Esc"; color: "#5A5055"; font { family: Theme.mono; pixelSize: 11 } }
      }
    }
  }

  component PaneBtn: MouseArea {
    id: pb
    property string label
    property string tag
    width: parent.width; height: 36; hoverEnabled: true
    Rectangle { anchors.fill: parent; radius: 4; color: pb.containsMouse ? Qt.rgba(1, 59 / 255, 59 / 255, 0.06) : "transparent"; border.color: pb.containsMouse ? lw.red : "transparent" }
    Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; rotation: 45; color: lw.red }
    Text { x: 28; width: parent.width - 80; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; textFormat: Text.PlainText; text: pb.label; color: lw.cream; font { family: Theme.sans; pixelSize: 13; weight: Font.DemiBold } }
    Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: pb.tag; color: lw.grey; font { family: Theme.sans; pixelSize: 12; bold: true } }
  }
}
