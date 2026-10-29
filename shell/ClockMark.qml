// Time in the digits font plus the part of the day:
//   ka   → დილის / შუადღის / საღამოს / ღამის set vertically beside the time, as tall as the digits
//   ampm → "5:15 AM" on one line (AM smaller, on the same baseline)
// fitWidth > 0: the whole thing spans exactly that width. A hidden copy is measured at size 100 and
// the real one scaled from it, so the match holds for every time, word and font.
import QtQuick

Item {
  id: cm
  property var date: new Date()
  property string fmt: "24"           // 24 | ka | ampm
  property real px: 30
  property real fitWidth: 0
  property color color: "#FFFFFF"
  property color wordColor: Theme.red
  property bool outline: false

  readonly property real size: fitWidth > 0 ? 100 * fitWidth / Math.max(1, probe.implicitWidth) : px
  implicitWidth: shown.implicitWidth
  implicitHeight: shown.implicitHeight

  Face { id: probe; sz: 100; opacity: 0 }   // opacity, not visible: hidden items drop out of Row layout
  Face { id: shown; sz: cm.size }

  component Face: Row {
    id: f
    property real sz
    readonly property string time: Theme.time(cm.date, cm.fmt)
    readonly property string word: Theme.period(cm.date, cm.fmt)
    readonly property bool vertical: cm.fmt === "ka"
    spacing: word ? sz * (vertical ? 0.08 : 0.12) : 0

    Text {
      id: t
      text: f.time; color: cm.color
      style: cm.outline ? Text.Outline : Text.Normal; styleColor: "#000000"
      font { family: Theme.digits; pixelSize: Math.max(1, f.sz) }
    }
    TextMetrics { id: cap; font: t.font; text: f.time }

    // ka: vertical word, its length matched to the digits' cap height
    TextMetrics { id: wm; font.family: Theme.labelFor(text); font.pixelSize: 100; text: f.vertical ? f.word : "" }
    Item {
      visible: f.vertical && f.word !== ""
      width: visible ? vt.implicitHeight : 0; height: t.height
      Text {
        id: vt
        text: f.word; color: cm.wordColor
        style: cm.outline ? Text.Outline : Text.Normal; styleColor: "#000000"
        font { family: Theme.labelFor(text); pixelSize: Math.max(1, Math.min(f.sz * 0.22, cap.tightBoundingRect.height * 100 / Math.max(1, wm.advanceWidth))) }
        rotation: -90
        x: parent.width / 2 - width / 2
        y: t.baselineOffset - cap.tightBoundingRect.height / 2 - height / 2
      }
    }

    // ampm: same line, smaller, sharing the baseline
    Item {
      visible: !f.vertical && f.word !== ""
      width: visible ? am.implicitWidth : 0; height: t.height
      Text {
        id: am
        text: f.word; color: cm.wordColor
        style: cm.outline ? Text.Outline : Text.Normal; styleColor: "#000000"
        font { family: Theme.digits; pixelSize: Math.max(1, f.sz * 0.42) }
        y: t.baselineOffset - baselineOffset
      }
    }
  }
}
