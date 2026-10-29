// Embroidered notifications (Notifs2 · B): the border stitches itself on in thread, and the thread
// unpicking itself the way it came is the countdown. Timed-out cards stay in history (bell → NotifHistory);
// a click declines (dismisses) it for good.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
  id: nw
  required property var bar
  screen: bar.screen
  WlrLayershell.namespace: "pharnavos-notif"
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; left: true }
  margins { top: 56; left: 18 }
  // fixed size + mask: cards come and go without resizing the surface
  implicitWidth: 380; implicitHeight: 900
  color: "transparent"
  visible: nw.shownCount > 0 && !Rice.notifShowAll   // pop-ups step aside while the bell's panel is open
  mask: Region { item: stack }

  NotificationServer {
    id: server
    keepOnReload: false   // true keeps old ones across a reload but then new ones stop arriving (qs 0.3)
    bodySupported: true; bodyMarkupSupported: false
    actionsSupported: true; imageSupported: true; persistenceSupported: true
    onNotification: n => {
      n.tracked = true;
      const t = Object.assign({}, nw.times); t[n.id] = Date.now(); nw.times = t;
      // keep the newest 50 (critical ones are never dropped); n is not in the list yet
      const old = server.trackedNotifications.values.filter(x => x.urgency !== NotificationUrgency.Critical);
      for (let i = 0; i < old.length - 49; i++) old[i].dismiss();
    }
  }
  readonly property var all: server.trackedNotifications.values
  readonly property int shownCount: all.filter(n => !Rice.seen[n.id]).length
  property var times: ({})
  NotifHistory { bar: nw.bar; server: server; times: nw.times; threadOf: nw.threadOf }
  Component.onCompleted: Rice.notifCount = Qt.binding(() => nw.all.length)

  function seen(n) { const s = Object.assign({}, Rice.seen); s[n.id] = true; Rice.seen = s }
  readonly property var threads: [Theme.red, "#E2B653", Theme.cream]
  function threadOf(n) {
    if (!n) return threads[0];
    if (n.urgency === NotificationUrgency.Critical) return Theme.red;
    let h = 0; for (const c of (n.appName || "?")) h = (h * 31 + c.charCodeAt(0)) >>> 0;
    return threads[h % threads.length];
  }

  Column {
    id: stack
    width: 360; spacing: 12

    // bound to the server's live model so existing cards keep their state when others arrive;
    // bottom-to-top puts the newest on top
    ListView {
      width: parent.width; height: contentHeight
      interactive: false; spacing: 12
      verticalLayoutDirection: ListView.BottomToTop
      model: server.trackedNotifications
      delegate: Card {
        required property var modelData
        n: modelData
        visible: !Rice.seen[modelData.id]
        height: visible ? implicitHeight : 0
      }
    }
  }

  component Card: Item {
    id: card
    property var n
    readonly property color thread: nw.threadOf(n)
    readonly property bool critical: n?.urgency === NotificationUrgency.Critical
    readonly property int timeout: (n?.expireTimeout ?? 0) > 0 ? n.expireTimeout : 6000
    property real sewn: 0       // border stitched on: 0 → 1
    property real unpicked: 0   // countdown: 0 → 1 (thread pulled out from the start)
    property bool leaving: false
    width: 360; implicitHeight: Math.max(110, content.implicitHeight + 52)

    Component.onCompleted: sew.start()
    onVisibleChanged: if (visible && leaving) { leaving = false; unpicked = 0; sew.start() }
    NumberAnimation { id: sew; target: card; property: "sewn"; from: 0; to: 1; duration: 900; easing.type: Easing.InOutQuad
      onFinished: if (!card.critical && !Rice.notifShowAll) countdown.start() }
    NumberAnimation { id: countdown; target: card; property: "unpicked"; from: 0; to: 1; duration: card.timeout
      paused: hover.containsMouse && running
      onFinished: card.leave(false) }
    NumberAnimation { id: quick; target: card; property: "unpicked"; to: 1; duration: 260; easing.type: Easing.InQuad
      onFinished: card.finish() }
    property bool dismissing: false
    function leave(dismiss) { if (leaving) return; leaving = true; dismissing = dismiss; countdown.stop(); quick.start() }
    function finish() { if (!n) return; if (dismissing || n.transient) n.dismiss(); else nw.seen(n) }

    MouseArea {
      id: hover
      anchors.fill: parent; hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      // left click declines (dismiss); right click opens the app when it offers that
      onClicked: m => {
        if (m.button === Qt.RightButton) {
          const def = card.n.actions.find(a => a.identifier === "default");
          if (def) def.invoke();
        }
        card.leave(true);
      }
    }

    Rectangle { anchors.fill: parent; radius: 4; color: "#0B090A"; opacity: card.leaving ? 1 - card.unpicked : 1 }

    Stitch { width: card.width; height: card.implicitHeight; thread: card.thread; from: card.unpicked; to: card.sewn }
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      // faint running stitch inside
      ShapePath {
        strokeColor: Qt.rgba(card.thread.r, card.thread.g, card.thread.b, 0.45 * card.sewn); strokeWidth: 1; fillColor: "transparent"
        strokeStyle: ShapePath.DashLine; dashPattern: [2, 3]
        PathRectangle { x: 15; y: 15; width: card.width - 30; height: card.implicitHeight - 30 }
      }
    }
    // cross-stitch corner diamonds
    Repeater {
      model: [[24, 22], [card.width - 32, 22], [24, card.implicitHeight - 30], [card.width - 32, card.implicitHeight - 30]]
      Item {
        required property var modelData
        x: modelData[0]; y: modelData[1]; width: 8; height: 8; opacity: card.sewn * (card.leaving ? 1 - card.unpicked : 1)
        Rectangle { x: 2; y: 0; width: 2; height: 6; color: card.thread }
        Rectangle { x: 0; y: 2; width: 6; height: 2; color: card.thread }
      }
    }

    Row {
      id: content
      x: 38; y: 26; width: parent.width - 76; spacing: 12
      opacity: Math.max(0, (card.sewn - 0.55) / 0.45) * (card.leaving ? 1 - card.unpicked : 1)
      Column {
        width: parent.width; spacing: 2
        Text { width: parent.width; elide: Text.ElideRight; text: card.n?.summary ?? ""; textFormat: Text.PlainText; color: "#FFFFFF"; font { family: Theme.sans; pixelSize: 16; weight: Font.ExtraBold } }
        Text { width: parent.width; text: card.n?.body ?? ""; textFormat: Text.PlainText; visible: text !== ""; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; color: "#C9C1C4"; font { family: Theme.sans; pixelSize: 13 } }
        Row {
          visible: (card.n?.actions ?? []).filter(a => a.identifier !== "default").length > 0
          spacing: 6; topPadding: 6
          Repeater {
            model: (card.n?.actions ?? []).filter(a => a.identifier !== "default")
            MouseArea {
              id: act
              required property var modelData
              width: actT.implicitWidth + 20; height: 26; hoverEnabled: true
              onClicked: { modelData.invoke(); card.leave(!card.n.resident) }
              Rectangle { anchors.fill: parent; radius: 13; color: act.containsMouse ? card.thread : "transparent"; border.color: card.thread }
              Text { id: actT; anchors.centerIn: parent; text: act.modelData.text; color: act.containsMouse ? "#070607" : Theme.cream; font { family: Theme.sans; pixelSize: 12; bold: true } }
            }
          }
        }
      }
    }

  }
}
