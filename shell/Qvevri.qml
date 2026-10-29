// A qvevri (Georgian clay wine vessel) whose wine level is a percentage: lipped mouth, short neck,
// wide shoulders in the upper third, egg-shaped body tapering to the pointed base.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
  id: q
  property real level: 0          // 0..100
  property string icon: ""        // SVG path in a 24×24 box, stamped into the clay
  property color wine: "#B0151F"
  property color hot: "#FF3B3B"
  readonly property bool alarm: level > 85
  // the level is by volume: height fraction holding 0,10,…,100 % of this shape's volume
  readonly property var volH: [0, 0.221, 0.323, 0.406, 0.479, 0.546, 0.613, 0.677, 0.746, 0.827, 1.0]
  function fillHeight(v) {
    v = Math.max(0, Math.min(100, v)) / 10;
    const i = Math.min(9, Math.floor(v));
    return volH[i] + (volH[i + 1] - volH[i]) * (v - i);
  }
  width: 16; height: 24

  // outline in a 16×24 box
  readonly property string path: "M6 0 L10 0 L10.5 1.3 L9.7 2.3 C13 3.1 16 5.6 16 9.2 C16 14.2 11.6 20 8.7 23.5 Q8 24.3 7.3 23.5 C4.4 20 0 14.2 0 9.2 C0 5.6 3 3.1 6.3 2.3 L5.5 1.3 Z"

  Shape {
    anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
    ShapePath { fillColor: "#211B1D"; strokeColor: "#6A5A5E"; strokeWidth: 0.9; PathSvg { path: q.path } }
  }
  // wine, clipped to the vessel
  Item {
    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 0.2 }
    Rectangle {
      anchors.bottom: parent.bottom; width: parent.width
      height: parent.height * q.fillHeight(q.level)
      color: q.alarm ? q.hot : q.wine
      Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
      SequentialAnimation on opacity { running: q.level > 95; loops: Animation.Infinite; NumberAnimation { to: 0.45; duration: 400 } NumberAnimation { to: 1; duration: 400 } }
    }
  }
  Shape {
    id: mask
    anchors.fill: parent; visible: false; layer.enabled: true; preferredRendererType: Shape.CurveRenderer
    ShapePath { fillColor: "white"; strokeWidth: 0; strokeColor: "transparent"; PathSvg { path: q.path } }
  }
  // stamp: the icon pressed into the clay; where the wine covers it, it turns dark
  component Stamp: Shape {
    id: stamp
    property color ink
    x: 4.4; y: 6.6; width: 7.2; height: 7.2; preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: stamp.ink; strokeWidth: 0.75; fillColor: "transparent"
      capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; scale: Qt.size(0.3, 0.3)
      PathSvg { path: q.icon }
    }
  }
  Stamp { visible: q.icon !== ""; ink: "#9A8C90" }
  Item {
    visible: q.icon !== ""
    anchors.bottom: parent.bottom; width: parent.width; clip: true
    height: parent.height * q.fillHeight(q.level)
    Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Stamp { ink: "#070607"; y: 6.6 - (q.height - parent.height) }
  }

  // the rim drawn on top so the mouth stays crisp
  Shape {
    anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
    ShapePath { fillColor: "transparent"; strokeColor: "#6A5A5E"; strokeWidth: 1; PathSvg { path: "M5.5 1.3 L10.5 1.3" } }
  }
}
