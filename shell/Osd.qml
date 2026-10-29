// Volume + brightness pop-ups (Osd3).
// Sound: a collage drinking horn (ყანწი) blows ink sound-waves along the
// bottom of the screen. One signal drives it all — the bar's cava bands when music plays, a soft idle
// pulse otherwise: wave height, the arcs pushed out of the horn's mouth, and the horn's kick.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

PanelWindow {
  id: osd
  required property var bar
  screen: bar.screen
  WlrLayershell.namespace: "pharnavos-osd"
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore
  anchors { bottom: true }
  implicitWidth: 740; implicitHeight: 320
  color: "transparent"
  mask: Region {}            // never takes clicks
  visible: slide > 0.001

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property real vol: sink?.audio.volume ?? 0
  readonly property bool muted: sink?.audio.muted ?? false

  // ---- show on change (not on startup) --------------------------------------------------
  property bool armed: false
  Timer { running: true; interval: 1500; onTriggered: osd.armed = true }
  property real slide: 0
  Behavior on slide { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
  Timer { id: hide; interval: 2400; onTriggered: osd.slide = 0 }
  property string mode: "vol"
  function show(m) { if (!armed) return; mode = m ?? "vol"; slide = 1; hide.restart() }

  // brightness: set by whoever changes it (ddcutil wrapper / keybind) via `ipc call osd brightness N`
  property real bri: 0.7
  IpcHandler {
    target: "osd"
    function brightness(v: int): void {
      // popping up: jump to the new level (no glide from wherever it was last time); open: glide to it
      const f = Math.max(0, Math.min(100, v)) / 100;
      glide.enabled = osd.slide > 0 && osd.mode === "bri";
      osd.bri = f; osd.shownBri = f; glide.enabled = true; osd.show("bri")
    }
  }
  Connections {
    target: osd.sink?.audio ?? null
    function onVolumeChanged() { osd.show("vol") }
    function onMutedChanged() { osd.show("vol") }
  }

  // ---- the signal ------------------------------------------------------------------------
  property int t: 0
  property real kick: 0
  property real inten: 0
  property real bassAvg: 0
  property int lastBeat: 0
  property var arcs: []      // { born, str }
  Timer {
    interval: 60; repeat: true; running: osd.visible && osd.mode === "vol"
    onTriggered: {
      const t = osd.t + 1, level = osd.muted ? 0 : osd.vol;
      const b = osd.bar.bands, bass = (b[0] + b[1] + b[2]) / 300, avg = b.reduce((x, y) => x + y, 0) / (b.length * 100);
      const playing = osd.bar.playing;
      // a beat = bass well above its recent average (with a short cooldown) while music plays,
      // else a slow idle pulse
      const beat = playing ? bass > osd.bassAvg * 1.25 && bass > 0.15 && t - osd.lastBeat > 4 : t % 9 === 0;
      osd.bassAvg = osd.bassAvg * 0.9 + bass * 0.1;
      if (beat) osd.lastBeat = t;
      osd.kick = beat ? 1 : osd.kick * 0.78;
      osd.inten = level * (playing ? 0.3 + 0.7 * Math.min(1, avg * 1.6) : 0.35 + 0.4 * Math.pow(Math.max(0, Math.sin(t * 0.21)), 2)) + level * 0.45 * osd.kick;
      let a = osd.arcs.filter(x => t - x.born < 18);
      if (beat && level > 0) a = a.concat([{ born: t, str: Math.min(1, osd.inten) }]);
      osd.arcs = a.slice(-6);
      osd.t = t;
    }
  }
  readonly property color ink: muted ? "#5A5055" : Theme.red

  // the wave runs as far as the volume goes: 100% reaches the end of the dotted track
  readonly property real trackEnd: 584   // leaves room for "100" after the tip inside the 740 px stage
  property real reach: 250 + Math.max(24, (trackEnd - 250) * (muted ? 0 : vol))
  Behavior on reach { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
  function wave(ph, k) {
    const out = [], amp = (muted ? 0 : inten) * 95, w = Math.max(1, reach - 250);
    for (let x = 250; x <= reach; x += 5) {
      const env = Math.pow(Math.sin((x - 250) / w * Math.PI), 1.6);   // tapers before the tip
      out.push(Qt.point(x, 150 - env * amp * k * (Math.sin(x * 0.07 + t * 0.55 + ph) * 0.7 + Math.sin(x * 0.19 - t * 0.9 + ph) * 0.3)));
    }
    return out;
  }

  Item {
    id: stage
    visible: osd.mode === "vol"
    width: 740; height: 220
    y: 100 + 240 * (1 - osd.slide)

    // 100% track
    Shape {
      anchors.fill: parent
      ShapePath { strokeColor: Qt.rgba(237 / 255, 230 / 255, 218 / 255, 0.18); strokeWidth: 2; fillColor: "transparent"; strokeStyle: ShapePath.DashLine; dashPattern: [2, 3]; startX: 250; startY: 150; PathLine { x: osd.trackEnd; y: 150 } }
    }
    // the painted wave
    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: !osd.muted; shadowColor: Theme.red; shadowBlur: 0.4; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
      Shape {
        anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
        ShapePath { strokeColor: Qt.rgba(osd.ink.r, osd.ink.g, osd.ink.b, 0.35); strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; PathPolyline { path: osd.wave(1.7, 0.6) } }
        ShapePath { strokeColor: osd.ink; strokeWidth: 7; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; PathPolyline { path: osd.wave(0, 1) } }
      }
    }

    // arcs pushed out of the horn's mouth: size, thickness and brightness = loudness of that beat
    Repeater {
      model: osd.arcs
      Shape {
        required property var modelData
        readonly property real age: (osd.t - modelData.born) / 18
        x: 186; y: 96; width: 120; height: 140
        transformOrigin: Item.Left
        scale: 0.55 + age * (0.8 + modelData.str * 1.2)
        opacity: (1 - age) * (0.35 + modelData.str * 0.65)
        preferredRendererType: Shape.CurveRenderer
        ShapePath { strokeColor: osd.ink; strokeWidth: 3 + modelData.str * 9; fillColor: "transparent"; capStyle: ShapePath.RoundCap; PathSvg { path: "M20 10 C80 40 80 100 20 130" } }
      }
    }

    // the horn
    Image {
      id: horn
      x: 10; y: 220 - 16 - height; width: 240; height: 240 * sourceSize.height / Math.max(1, sourceSize.width)
      source: "file://" + Quickshell.shellDir + "/assets/cutouts/horn.png"
      mipmap: true
      transformOrigin: Item.BottomLeft
      rotation: -osd.inten * 4; scale: 1 + osd.inten * 0.05
      layer.enabled: true
      layer.effect: MultiEffect { saturation: osd.muted ? -1 : 0; brightness: osd.muted ? -0.4 : 0; shadowEnabled: true; shadowColor: "#99000000"; shadowVerticalOffset: 8; shadowBlur: 0.5 }
    }
    // mute: a painted X over the horn
    Shape {
      visible: osd.muted
      x: 170; y: 220 - 30 - 110; width: 110; height: 110; preferredRendererType: Shape.CurveRenderer
      ShapePath { strokeColor: Theme.red; strokeWidth: 12; fillColor: "transparent"; capStyle: ShapePath.RoundCap; PathSvg { path: "M14 14 L96 96 M96 14 L14 96" } }
    }

    // the level rides the tip of the wave
    Text {
      x: osd.reach + 20; y: 150 - height / 2
      text: osd.muted ? Rice.t("დადუმებული", "muted") : Math.round(osd.vol * 100)
      color: osd.ink; style: Text.Outline; styleColor: "#000000"
      font { family: osd.muted ? Theme.labelFor(text) : Theme.digits; pixelSize: osd.muted ? 20 : 46 }
    }
  }

  // ---- light: the collage sun rises over a brushed ink horizon ---------------------------------
  // sun height = brightness; the gold horizon line grows outward from the centre (full width = 100%)
  readonly property var horizon: {
    // the horizon curve "M-10 30 C120 20 260 38 380 28 S620 22 750 32", sampled, with arc lengths
    const segs = [[[-10, 30], [120, 20], [260, 38], [380, 28]], [[380, 28], [500, 18], [620, 22], [750, 32]]];
    const pts = [];
    for (const g of segs) for (let i = pts.length ? 1 : 0; i <= 60; i++) {
      const t = i / 60, u = 1 - t;
      pts.push(Qt.point(u*u*u*g[0][0] + 3*u*u*t*g[1][0] + 3*u*t*t*g[2][0] + t*t*t*g[3][0], u*u*u*g[0][1] + 3*u*u*t*g[1][1] + 3*u*t*t*g[2][1] + t*t*t*g[3][1]));
    }
    const len = [0];
    for (let i = 1; i < pts.length; i++) len.push(len[i - 1] + Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y));
    return { pts, len };
  }
  // the middle part of the horizon, f of its length; its ends are interpolated, so it grows smoothly
  // instead of in sample-sized steps
  function horizonPart(f) {
    const P = horizon.pts, D = horizon.len, L = D[D.length - 1], a = L * (0.5 - f / 2), b = L * (0.5 + f / 2);
    const at = d => { let i = 1; while (i < D.length - 1 && D[i] < d) i++; const k = (d - D[i - 1]) / Math.max(1e-6, D[i] - D[i - 1]); return Qt.point(P[i - 1].x + (P[i].x - P[i - 1].x) * k, P[i - 1].y + (P[i].y - P[i - 1].y) * k) };
    return [at(a)].concat(P.filter((p, i) => D[i] > a && D[i] < b), [at(b)]);
  }
  // a polyline thickened into a closed band (so it can take a gradient fill)
  function band(pts, w) {
    const top = [], bot = [];
    for (let i = 0; i < pts.length; i++) {
      const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
      const dx = b.x - a.x, dy = b.y - a.y, l = Math.hypot(dx, dy) || 1, nx = -dy / l * w / 2, ny = dx / l * w / 2;
      top.push(Qt.point(pts[i].x + nx, pts[i].y + ny)); bot.unshift(Qt.point(pts[i].x - nx, pts[i].y - ny));
    }
    return top.concat(bot, [top[0]]);
  }
  property real shownBri: 0.7   // set with bri by brightness(); animated
  Behavior on shownBri { id: glide; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

  Item {
    id: sunStage
    visible: osd.mode === "bri"
    width: 740; height: 300
    y: 20 + 320 * (1 - osd.slide)

    Shape {
      anchors.fill: parent
      ShapePath {
        strokeWidth: 0; strokeColor: "transparent"
        fillGradient: RadialGradient {
          // must reach transparent inside the 740×300 area, or its edges show as a rectangle
          centerX: 370; centerY: 300; focalX: 370; focalY: 300; centerRadius: 290
          GradientStop { position: 0; color: Qt.rgba(1, 181 / 255, 71 / 255, osd.shownBri * 0.3) }
          GradientStop { position: 0.6; color: Qt.rgba(1, 181 / 255, 71 / 255, osd.shownBri * 0.08) }
          GradientStop { position: 1; color: Qt.rgba(1, 181 / 255, 71 / 255, 0) }
        }
        PathRectangle { width: 740; height: 300 }
      }
    }
    // the sun is clipped at the horizon: below it nothing may show, even while the pop-up slides in
    Item {
      width: 740; height: 262; clip: true
      Image {
        id: sun
        width: 190; height: 190; x: 370 - 95
        y: 300 - 190 - (-150 + osd.shownBri * 230)
        source: "file://" + Quickshell.shellDir + "/assets/cutouts/sun.png"
        sourceSize: Qt.size(380, 380); mipmap: true
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#FFB547"; shadowBlur: 0.2 + osd.shownBri * 0.5; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
        Timer { interval: 33; repeat: true; running: sunStage.visible && osd.visible; onTriggered: sun.rotation = (sun.rotation + 0.3) % 360 }
      }
    }
    // horizon: ink ground hides the set sun, gold line = level. Ground and base line fade to
    // transparent at both ends (gradient fills) so the pop-up has no hard edges; the gold line
    // tops out inside the fade (86% of the width at 100%).
    Shape {
      x: 0; y: 230; width: 740; height: 70; preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: 0; strokeColor: "transparent"
        fillGradient: LinearGradient {
          x1: 0; y1: 0; x2: 740; y2: 0
          GradientStop { position: 0; color: "#000B090A" }
          GradientStop { position: 0.14; color: "#0B090A" }
          GradientStop { position: 0.86; color: "#0B090A" }
          GradientStop { position: 1; color: "#000B090A" }
        }
        PathSvg { path: "M0 30 C120 20 260 38 380 28 S620 22 740 32 L740 70 L0 70 Z" }
      }
      ShapePath {
        strokeWidth: 0; strokeColor: "transparent"
        fillGradient: LinearGradient {
          x1: 0; y1: 0; x2: 740; y2: 0
          GradientStop { position: 0; color: "#002A2226" }
          GradientStop { position: 0.14; color: "#2A2226" }
          GradientStop { position: 0.86; color: "#2A2226" }
          GradientStop { position: 1; color: "#002A2226" }
        }
        PathPolyline { path: osd.band(osd.horizon.pts, 9) }
      }
    }
    Shape {
      x: 0; y: 230; width: 740; height: 70; preferredRendererType: Shape.CurveRenderer
      visible: osd.shownBri > 0.01
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#FFB547"; shadowBlur: 0.2 + osd.shownBri * 0.4; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
      ShapePath { strokeColor: "#FFB547"; strokeWidth: 10; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; PathPolyline { path: osd.horizonPart(osd.shownBri * 0.86) } }
    }
    Column {
      anchors { right: parent.right; rightMargin: 30; bottom: parent.bottom; bottomMargin: 84 }
      Text { anchors.right: parent.right; text: Math.round(osd.shownBri * 100); color: "#FFB547"; style: Text.Outline; styleColor: "#000000"; font { family: Theme.digits; pixelSize: 72 } }
      Text { anchors.right: parent.right; text: Rice.t("სიკაშკაშე", "brightness"); color: "#FFFFFF"; style: Text.Outline; styleColor: "#000000"; font { family: Theme.labelFor(text); pixelSize: 16 } }
    }
  }
}
