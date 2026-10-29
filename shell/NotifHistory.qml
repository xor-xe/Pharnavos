// The bell's notification centre: hangs off the bar's left edge (mirror of the control centre).
// One list, critical first then newest; consecutive notifications from the same app stack into one
// card ("+N სხვა"). Each card is the pop-up's stitched card. Click = open the app, right-click = dismiss (the whole stack).
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland

PanelWindow {
  id: hw
  required property var bar
  required property var server
  required property var times            // id → arrival time (ms)
  required property var threadOf         // n → thread colour
  screen: bar.screen
  WlrLayershell.namespace: "pharnavos-notif-history"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: Rice.notifShowAll ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; left: true }
  margins { top: 46 }
  implicitWidth: 420 + 30; implicitHeight: (screen?.height ?? 1440) - 46   // fixed size (+30 px for the cloth's sway): content never resizes the surface
  color: "transparent"
  mask: Region { item: panel }
  property bool mapped: false
  visible: mapped

  readonly property color red: Theme.red
  readonly property color cream: Theme.cream
  readonly property color grey: "#8C8186"

  HyprlandFocusGrab { windows: [hw, hw.bar]; active: Rice.notifShowAll; onCleared: Rice.notifShowAll = false }

  // ---- open / close: the same cloth-flag entrance as the control centre ---------------------
  // p = open progress, clk = ripple clock; once the ripple has died out the real panel is shown
  property real p: 0
  property real clk: 9
  readonly property real rippleT: Rice.notifShowAll ? Math.max(0, clk - 0.4) : clk + 0.15
  readonly property bool settled: Rice.notifShowAll && !inA.running && clk > 2.0
  NumberAnimation { id: inA; target: hw; property: "p"; to: 1; duration: 720; easing.type: Easing.OutCubic }
  NumberAnimation { id: outA; target: hw; property: "p"; to: 0; duration: 380; easing.type: Easing.InOutQuad; onFinished: { if (!Rice.notifShowAll) hw.mapped = false; for (const n of hw.leaving) hw.bye(n); hw.leaving = [] } }
  NumberAnimation { id: clkA; target: hw; property: "clk"; from: 0; to: 2.2; duration: 2200 }
  Connections {
    target: Rice
    function onNotifShowAllChanged() {
      if (Rice.notifShowAll) { hw.expanded = ({}); hw.now = Date.now(); hw.mapped = true; outA.stop(); inA.start(); panel.forceActiveFocus() }
      else { inA.stop(); outA.start() }
      clkA.restart();
    }
  }

  // ---- model -------------------------------------------------------------------------------
  property var expanded: ({})
  property real now: Date.now()
  Timer { interval: 30000; repeat: true; running: hw.mapped; onTriggered: hw.now = Date.now() }

  // critical first, then newest; consecutive same-app (non-critical) cards stack unless expanded
  readonly property var cards: {
    const all = server.trackedNotifications.values.slice().reverse();
    const crit = all.filter(n => n.urgency === NotificationUrgency.Critical);
    const rest = all.filter(n => n.urgency !== NotificationUrgency.Critical);
    const out = [];
    for (const n of crit.concat(rest)) {
      const last = out[out.length - 1], app = n.appName || "";
      if (last && n.urgency !== NotificationUrgency.Critical && last.app === app && !hw.expanded[app] && last.n.urgency !== NotificationUrgency.Critical) { last.more.push(n); continue; }
      out.push({ n, app, more: [] });
    }
    return out;
  }

  // the cards as rows keyed by their lead notification: delegates survive changes (a fresh array
  // would rebuild every card, so one dismissal flashed the whole list)
  readonly property var cardOf: { const m = {}; for (const c of cards) m[c.n.id] = c; return m }
  ListModel { id: rows }
  onCardsChanged: {
    const keys = cards.map(c => c.n.id);
    for (let i = 0; i < keys.length; i++) {
      if (i < rows.count && rows.get(i).key === keys[i]) continue;
      let j = i + 1; while (j < rows.count && rows.get(j).key !== keys[i]) j++;
      if (j < rows.count) rows.remove(i, j - i); else rows.insert(i, { key: keys[i] });
    }
    if (rows.count > keys.length) rows.remove(keys.length, rows.count - keys.length);
  }
  Component.onCompleted: cardsChanged()

  // clicked: open the app at once, but let go of the notification only once the panel has closed,
  // so the list doesn't shift under the closing animation
  property var leaving: []
  // a notification may have expired or been closed by its app meanwhile
  function bye(n) { if (hw.server.trackedNotifications.values.includes(n)) n.dismiss() }
  function ago(n) {
    const t = hw.times[n.id];
    if (!t) return "";
    const s = (hw.now - t) / 1000;
    if (s < 60) return Rice.t("ახლა", "now");
    if (s < 3600) return Math.floor(s / 60) + Rice.t(" წთ წინ", " min ago");
    if (s < 86400) return Math.floor(s / 3600) + Rice.t(" სთ წინ", " h ago");
    const d = new Date(t);
    return d.getDate() + " " + Theme.monthsShort[d.getMonth()];
  }
  // a picture file in the notification (screenshot, download) shows as a thumbnail
  // a file path arrives as "/…", "file://…" or (image-path hint) "image://icon//…"
  function filePath(n) { const i = n.image || ""; return i.startsWith("image://icon//") ? i.slice(13) : i.startsWith("file://") ? i.slice(7) : i.startsWith("/") ? i : "" }
  function picture(n) { const p = hw.filePath(n); return p && /\.(png|jpe?g|webp|gif|bmp)$/i.test(p) ? "file://" + p : "" }
  function open(n) {
    const def = n.actions.find(a => a.identifier === "default");
    if (def) def.invoke();
    hw.leaving = hw.leaving.concat([n]);
    Rice.notifShowAll = false;
  }

  // test hooks (no mouse clicks from scripts): same code paths as the UI
  IpcHandler {
    target: "notif-test"
    function dismiss(i: int): void { const d = cardsRep.itemAt(i); if (d) d.drop() }
    function open(i: int): void { const c = hw.cards[i]; if (c) hw.open(c.n) }
    function action(i: int, k: int): void { const c = hw.cards[i]; const a = c ? c.n.actions.filter(a => a.identifier !== "default")[k] : null; if (a) a.invoke() }
    function expand(app: string): void { const e = Object.assign({}, hw.expanded); e[app] = true; hw.expanded = e }
    function clear(): void { list.opacity = 0 }
    function count(): int { return hw.cards.length }
    function list(): string { return hw.server.trackedNotifications.values.map(n => n.appName + ":" + n.urgency).join(", ") }
  }

  // ---- panel -------------------------------------------------------------------------------
  ShaderEffect {
    x: panel.x; y: 0; width: panel.width; height: panel.height
    visible: !hw.settled
    mesh: GridMesh { resolution: Qt.size(24, 90) }
    property variant source: ShaderEffectSource { sourceItem: panel; hideSource: !hw.settled; live: true }
    property real p: Math.max(0.0001, hw.p)
    property real t: hw.rippleT
    property real amp: 1.0
    property size dim: Qt.size(width, height)
    vertexShader: "file://" + Quickshell.shellDir + "/shaders/flag.vert.qsb"
    fragmentShader: "file://" + Quickshell.shellDir + "/shaders/flag.frag.qsb"
  }
  Rectangle {
    id: panel
    width: 420; height: Math.min(hw.height, col.implicitHeight + 8)
    color: "#070607"; border.color: "#2A2226"
    radius: 0; bottomRightRadius: 28
    focus: true
    Keys.onEscapePressed: Rice.notifShowAll = false
    Rectangle { x: 1; width: parent.width - 2; height: 2; color: "#070607" }   // merge with the bar

    Row {   // zig-zag hem, like the control centre
      width: parent.width; height: 8; clip: true; opacity: 0.7
      Repeater { model: Math.ceil(420 / 8); Shape { width: 8; height: 8; ShapePath { fillColor: hw.red; strokeWidth: 0; strokeColor: "transparent"; PathSvg { path: "M0 0 L4 4 L8 0 Z" } } } }
    }

    Column {
      id: col
      y: 8; width: parent.width

      Item {
        width: parent.width; height: 70
        Column {
          x: 20; anchors.verticalCenter: parent.verticalCenter; spacing: 6
          Text { id: titleT; text: Rice.t("შეტყობინებები", "Notifications"); color: "#FFFFFF"; font { family: Theme.headFor(text); pixelSize: 28 } }
          Text { visible: hw.server.trackedNotifications.values.length > 0; text: hw.server.trackedNotifications.values.length + Rice.t(" შეტყობინება", hw.server.trackedNotifications.values.length === 1 ? " notification" : " notifications"); color: hw.grey; font { family: Theme.sans; pixelSize: 12 } }
        }
        MouseArea {
          id: clearBtn
          visible: hw.cards.length > 0
          anchors.right: parent.right; anchors.rightMargin: 20
          y: titleT.parent.y + titleT.y + (titleT.height - height) / 2
          width: clearT.implicitWidth + 28; height: 30; hoverEnabled: true
          onClicked: list.opacity = 0
          Rectangle { anchors.fill: parent; radius: 15; color: "#0E0B0D"; border.color: clearBtn.containsMouse ? hw.red : "#3A2E33" }
          Text { id: clearT; anchors.centerIn: parent; text: Rice.t("გასუფთავება", "Clear"); color: hw.cream; font { family: Theme.sans; pixelSize: 12; bold: true } }
        }
      }

      Item { width: 1; height: 14 }   // breathing room under the count line
      Flickable {
        x: 16; width: parent.width - 32
        height: Math.min(list.implicitHeight, hw.height - 70 - 14 - 30)
        contentHeight: list.implicitHeight; clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: list
          width: parent.width
          Behavior on opacity { NumberAnimation { duration: 160 } }
          onOpacityChanged: if (opacity === 0) { for (const n of hw.server.trackedNotifications.values.slice()) n.dismiss(); opacity = 1 }
          Repeater { id: cardsRep; model: rows; HCard { required property string key; c: hw.cardOf[key] ?? null } }
          // empty state
          Item {
            visible: hw.cards.length === 0
            width: parent.width; height: 220
            Column {
              anchors.centerIn: parent; spacing: 10
              Item {
                anchors.horizontalCenter: parent.horizontalCenter; width: 84; height: 84
                Shape {
                  anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
                  ShapePath { strokeColor: "#3A2E33"; strokeWidth: 2; fillColor: "transparent"; strokeStyle: ShapePath.DashLine; dashPattern: [3, 2]; PathAngleArc { centerX: 42; centerY: 42; radiusX: 41; radiusY: 41; startAngle: 0; sweepAngle: 360 } }
                }
                Shape {
                  anchors.centerIn: parent; width: 30; height: 40; preferredRendererType: Shape.CurveRenderer
                  ShapePath { strokeColor: "#5A4E53"; strokeWidth: 2.4; fillColor: "transparent"; capStyle: ShapePath.RoundCap; scale: Qt.size(1.5, 1.54); PathSvg { path: "M10 2 C9.4 9 10.6 17 10 24 M2 11 Q10 6 18 11" } }
                }
              }
              Text { anchors.horizontalCenter: parent.horizontalCenter; text: Rice.t("მშვიდობაა", "All quiet"); color: "#C9C1C4"; font { family: Theme.sans; pixelSize: 18; weight: Font.Medium; letterSpacing: 0.5 } }
            }
          }
          Item { width: 1; height: 8 }
        }
      }
    }
  }

  // ---- one card ----------------------------------------------------------------------------
  component HCard: MouseArea {
    id: hc
    property var c
    readonly property var n: c ? c.n : null
    property bool gone: false
    // fold away, then dismiss (the row goes once the notifications are gone)
    function drop() { gone = true; dropT.start() }
    Timer { id: dropT; interval: 200; onTriggered: { const c = hc.c; for (const x of c.more) hw.bye(x); hw.bye(c.n) } }
    readonly property color thread: n ? hw.threadOf(n) : "transparent"
    readonly property bool critical: n?.urgency === NotificationUrgency.Critical
    readonly property string pic: n ? hw.picture(n) : ""
    readonly property var acts: n ? n.actions.filter(a => a.identifier !== "default") : []
    visible: n !== null
    width: parent.width; height: gone || !n ? 0 : body.implicitHeight + 32 + 10   // + the gap to the next card
    opacity: gone ? 0 : 1; clip: true
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 150 } }
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: m => { if (m.button === Qt.RightButton) hc.drop(); else hw.open(n) }

    Item {
      width: parent.width; height: body.implicitHeight + 32
      Rectangle { anchors.fill: parent; color: hc.containsMouse ? "#110D0F" : "#0B090A" }
      Stitch { anchors.fill: parent; inset: 5; stroke: 2; thread: hc.thread }
    }

    Row {
      id: body
      x: 18; y: 16; width: parent.width - 36; spacing: 12
      Column {
        width: parent.width; spacing: 2
        Item {
          width: parent.width; height: 22
          Row {
            spacing: 8
            Text {
              width: Math.min(implicitWidth, parent.parent.width - agoT.implicitWidth - 12 - (hc.critical ? tag.width + 8 : 0))
              elide: Text.ElideRight; text: hc.n?.summary ?? ""; textFormat: Text.PlainText; color: "#FFFFFF"; font { family: Theme.sans; pixelSize: 15; weight: Font.ExtraBold }
            }
            Rectangle {
              id: tag
              visible: hc.critical; anchors.verticalCenter: parent.verticalCenter
              width: critT.implicitWidth + 12; height: 15; radius: 4; color: hw.red
              Text { id: critT; anchors.centerIn: parent; text: Rice.t("მნიშვნელოვანი", "important"); color: "#FFFFFF"; font { family: Theme.sans; pixelSize: 10; weight: Font.Black } }
            }
          }
          Text { id: agoT; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: hc.n ? hw.ago(hc.n) : ""; color: hw.grey; font { family: Theme.sans; pixelSize: 11 } }
        }
        Text {
          visible: text !== ""
          width: parent.width; text: hc.n?.body ?? ""; textFormat: Text.PlainText
          wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
          color: "#C9C1C4"; font { family: Theme.sans; pixelSize: 13 }
        }
        Item {
          visible: hc.pic !== ""
          width: parent.width; height: visible ? 104 : 0
          Image { y: 8; width: parent.width; height: 96; source: hc.pic; sourceSize: Qt.size(width * 2, 192); fillMode: Image.PreserveAspectCrop; clip: true }
        }
        Row {
          visible: hc.acts.length > 0
          topPadding: 8; spacing: 6
          Repeater {
            model: hc.acts
            MouseArea {
              id: actB
              required property var modelData
              width: actT.implicitWidth + 24; height: 26; hoverEnabled: true
              onClicked: { modelData.invoke(); if (!hc.n.resident) hc.drop() }
              Rectangle { anchors.fill: parent; radius: 13; color: actB.containsMouse ? hc.thread : "transparent"; border.color: hc.thread }
              Text { id: actT; anchors.centerIn: parent; text: actB.modelData.text; color: actB.containsMouse ? "#070607" : hw.cream; font { family: Theme.sans; pixelSize: 11; bold: true } }
            }
          }
        }
        MouseArea {
          visible: (hc.c?.more.length ?? 0) > 0
          width: moreT.implicitWidth; height: visible ? 24 : 0
          onClicked: { const e = Object.assign({}, hw.expanded); e[hc.c.app] = true; hw.expanded = e }
          Text { id: moreT; y: 6; text: "+" + (hc.c?.more.length ?? 0) + Rice.t(" სხვა ▾", " more ▾"); color: hc.thread; font { family: Theme.sans; pixelSize: 12; bold: true } }
        }
      }
    }
  }
}
