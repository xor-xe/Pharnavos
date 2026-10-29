// Dashed thread sewn around a rectangle, clockwise from the top-left corner. Shows the stretch of
// the perimeter between `from` and `to` (0–1), so animating `to` sews it on and `from` unpicks it.
import QtQuick
import QtQuick.Shapes

Shape {
  id: st
  property color thread: Theme.red
  property real from: 0
  property real to: 1
  property real inset: 7
  property real stroke: 4
  property real crawl: 0        // animate 0 → 2.5 for marching stitches

  readonly property real bw: width - 2 * inset
  readonly property real bh: height - 2 * inset
  readonly property real per: 2 * (bw + bh)
  function pt(d) {
    d = Math.max(0, Math.min(per, d));
    if (d <= bw) return Qt.point(inset + d, inset);
    if (d <= bw + bh) return Qt.point(inset + bw, inset + d - bw);
    if (d <= 2 * bw + bh) return Qt.point(inset + bw - (d - bw - bh), inset + bh);
    return Qt.point(inset, inset + bh - (d - 2 * bw - bh));
  }
  function seg(a, b) {
    const out = [pt(a)];
    for (const c of [bw, bw + bh, 2 * bw + bh]) if (c > a && c < b) out.push(pt(c));
    out.push(pt(b));
    return out;
  }

  preferredRendererType: Shape.CurveRenderer
  ShapePath {
    strokeColor: st.thread; strokeWidth: st.stroke; fillColor: "transparent"
    strokeStyle: ShapePath.DashLine; dashPattern: [1.5, 1]
    dashOffset: st.from * st.per / st.stroke + st.crawl   // still while the thread is pulled out
    capStyle: ShapePath.FlatCap; joinStyle: ShapePath.MiterJoin
    PathPolyline { path: st.seg(st.from * st.per, st.to * st.per) }
  }
}
