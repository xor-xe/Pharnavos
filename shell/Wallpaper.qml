// Text-art wallpaper: Rustaveli stanza along a Borjgali spiral / Vazha-Pshavela head stencil
// made of his verse. Port of the CCWall canvas prototype (design space 1600x900).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
  id: root
  required property var modelData
  screen: modelData
  // previews: only PHARNAVOS_PREVIEW=wall lifts the wallpaper over windows, and even then it never takes
  // clicks or keys (so a test run can't block the desktop)
  WlrLayershell.layer: Quickshell.env("PHARNAVOS_PREVIEW") === "wall" ? WlrLayer.Overlay : WlrLayer.Background
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}
  WlrLayershell.namespace: "pharnavos-wall"
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; bottom: true; left: true; right: true }
  color: "#000000"

  // settings live in Rice.cfg (edited from the control centre's ფონი tab)
  property string which: Quickshell.env("PHARNAVOS_WALL") || Rice.cfg.wallMode  // borj | vazha | dance | rot
  readonly property string anim: Rice.cfg.anim
  readonly property int speed: Rice.cfg.speed
  readonly property int spin: Rice.cfg.spin
  readonly property int size: Rice.cfg.size
  readonly property int shape: Rice.cfg.shape
  readonly property int contrast: Rice.cfg.contrast
  readonly property string ink: Rice.cfg.ink
  property int rotateMinutes: 10
  property string wallFont: Theme.wall

  property string mode: ""   // set once at start, then by go()
  property string text: ""
  property var glyphs: []
  readonly property int len: Math.max(1, text.length)
  readonly property real s: height / 900
  property real t: 0
  readonly property real pos: (t * (4 + speed * 0.6)) % (len + 12)

  function asset(p) { return Quickshell.shellDir + "/assets/" + p }
  FileView { id: rustFile; path: root.asset("texts/rustaveli.json"); blockLoading: true }
  FileView { id: vazhaFile; path: root.asset("texts/vazha.json"); blockLoading: true }
  // English: Rustaveli in Marjory Wardrop's public-domain translation (1912). Vazha in George Hewitt's
  // translations, which are free to read but not to redistribute: each machine downloads them from his site
  FileView { id: rustEnFile; path: root.asset("texts/rustaveli-en.json"); blockLoading: true }
  readonly property bool en: Rice.lang === "en"
  readonly property string vazhaEnPath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/pharnavos/vazha-hewitt.txt"
  FileView { id: vazhaEnFile; path: root.vazhaEnPath; blockLoading: true; printErrors: false }
  property var vazhaEn: []
  onEnChanged: { if (en) fetchVazha(); refresh() }
  function fetchVazha() {
    vazhaEn = parseHewitt(vazhaEnFile.text());
    if (!vazhaEn.length && !vazhaFetch.running) vazhaFetch.running = true;
  }
  Process {
    id: vazhaFetch
    command: ["sh", "-c", 'd=$(dirname "$1"); mkdir -p "$d" && curl -fsL --max-time 60 -o "$d/h.pdf" "$2" && pdftotext "$d/h.pdf" "$1.part" && mv "$1.part" "$1"; rm -f "$d/h.pdf"',
              "sh", root.vazhaEnPath, "https://www.georgehewitt.net/pdf/Translations_from_Vazha_Pshavela.pdf"]
    onExited: { vazhaEnFile.reload(); root.vazhaEn = root.parseHewitt(vazhaEnFile.text()); if (root.vazhaEn.length) root.refresh() }
  }
  // the poems come first, each closed by its date line; the stories (prose) follow
  function parseHewitt(t) {
    const i = t.indexOf("included below.");
    if (i < 0) return [];
    const date = /^((\d{1,2} )?(January|February|March|April|May|June|July|August|September|October|November|December) )?1[89]\d\d$/;
    const out = []; let cur = [], long = 0;
    for (const ln of t.slice(i + 15).split("\n")) {
      const s = ln.trim();
      long = s.length > 75 ? long + 1 : 0;
      if (long >= 3) break;
      if (!s || /^\d+$/.test(s) || /^\(.*\)$/.test(s) || s.startsWith("*")) continue;
      if (date.test(s)) { if (cur.length > 1) out.push({ t: cur[0], l: cur.slice(1) }); cur = []; continue; }
      cur.push(s.replace(/\s*—\s*/g, " - ").replace(/…/g, "..."));   // the wall font lacks — and …
    }
    return out;
  }

  function pick() {
    const src = Rice.cfg.wallSrc === "r" || Rice.cfg.wallSrc === "v" ? Rice.cfg.wallSrc : mode === "borj" ? "r" : "v";
    // English Vazha until Hewitt's poems are downloaded (or offline): the portrait reads Rustaveli
    const k = !en ? src : src === "v" && vazhaEn.length ? "ve" : "re";
    const a = k === "ve" ? vazhaEn : JSON.parse(k === "r" ? rustFile.text() : k === "re" ? rustEnFile.text() : vazhaFile.text());
    // Vazha: four lines from one stanza (Hewitt: from one poem), never across a stanza break;
    // the short text repeats over the portrait
    const pool = k[0] === "r" ? a : a.filter(x => x.l.length >= 4);
    const v = pool[Math.floor(Math.random() * pool.length)];
    const q = 4 * Math.floor(Math.random() * Math.floor(v.l.length / 4));
    const lines = k[0] === "r" ? v.l : v.l.slice(q, q + 4);
    text = lines.join(" ").replace(/\s+/g, " ").trim() + " ";   // the space parts the repeats
    Rice.wallText = lines.join("\n");
    Rice.wallInfo = (k[0] === "r" ? "r:" + v.n : "v:" + v.t);   // ControlCenter words it in the UI language
  }

  function build() {
    if (mode === "dance") { glyphs = []; return }
    if (!text) return;
    if (mode === "borj") {
      // true Borjgali (Wikimedia path): each arm is a crescent between two cubics. Lanes of text run
      // from the centre to the tip, parallel to the arm's midline, filling the crescent.
      const bez = (p, t) => { const u = 1 - t; return [u*u*u*p[0][0] + 3*u*u*t*p[1][0] + 3*u*t*t*p[2][0] + t*t*t*p[3][0], u*u*u*p[0][1] + 3*u*u*t*p[1][1] + 3*u*t*t*p[2][1] + t*t*t*p[3][1]] };
      const inner = [[-10.294, 244.024], [-120.274, 194.616], [-114.952, 47.723], [-1.21, -0.128]];   // tip → centre
      const outer = [[-1.21, -0.128], [-182.399, -29.113], [-187.058, 257.58], [-10.294, 244.024]];  // centre → tip
      const K = 1.7 * shape / 100, F = Math.max(8, 13 * size / 100), N = 600, out = [];
      // crescent outline (design px) for point-in-shape tests, and the midline to run lanes along
      const poly = [], mid = [];
      for (let k = 0; k <= N; k++) { const p = bez(outer, k / N); poly.push([p[0] * K, p[1] * K]); }
      for (let k = 0; k <= N; k++) { const p = bez(inner, k / N); poly.push([p[0] * K, p[1] * K]); }
      // scanline table: for each design-px row, the x-intervals inside the crescent (fast inside test)
      const ys = poly.map(p => p[1]), y0 = Math.floor(Math.min(...ys)), y1 = Math.ceil(Math.max(...ys)), rows = [];
      for (let y = y0; y <= y1; y++) {
        const xs = [];
        for (let a = 0, b = poly.length - 1; a < poly.length; b = a++)
          if ((poly[a][1] > y) !== (poly[b][1] > y)) xs.push((poly[b][0] - poly[a][0]) * (y - poly[a][1]) / (poly[b][1] - poly[a][1]) + poly[a][0]);
        rows.push(xs.sort((p, q) => p - q));
      }
      const inside = (x, y) => {
        const r = rows[Math.round(y) - y0]; if (!r) return false;
        let c = false; for (const v of r) { if (v > x) break; c = !c; } return c;
      };
      for (let k = 0; k <= N; k++) { const t = k / N, a = bez(inner, 1 - t), b = bez(outer, t); mid.push([(a[0] + b[0]) / 2 * K, (a[1] + b[1]) / 2 * K]); }
      const fits = (x, y, nx, ny, tx, ty) => inside(x, y) && inside(x + nx * F * 0.42, y + ny * F * 0.42) && inside(x - nx * F * 0.42, y - ny * F * 0.42) && inside(x + tx * F * 0.3, y + ty * F * 0.3);
      // lane template for one arm, then rotate it 7 times
      const arm0 = [];
      const lanes = Math.ceil(130 * K / (F * 1.08));
      for (let l = -lanes; l <= lanes; l++) {
        const o = l * F * 1.08;
        let dist = 0, next = 0, px = null, py = null;
        for (let k = 1; k <= N; k++) {
          const tx0 = mid[k][0] - mid[k - 1][0], ty0 = mid[k][1] - mid[k - 1][1], tl = Math.hypot(tx0, ty0) || 1;
          const tx = tx0 / tl, ty = ty0 / tl, nx = -ty, ny = tx;
          const x = mid[k][0] + nx * o, y = mid[k][1] + ny * o;
          if (px !== null) dist += Math.hypot(x - px, y - py);
          px = x; py = y;
          if (dist < next) continue;
          if (!fits(x, y, nx, ny, tx, ty)) { next = dist + F * 0.25; continue; }
          arm0.push({ x, y, ang: Math.atan2(ty, tx), k, l });
          next = dist + F * 0.82;
        }
      }
      let n = 0;
      for (let arm = 0; arm < 7; arm++) {
        const rot = arm * 2 * Math.PI / 7, c = Math.cos(rot), sn = Math.sin(rot);
        for (const g of arm0) {
          const ch = text[n++ % text.length];
          out.push({ x: g.x * c - g.y * sn, y: g.x * sn + g.y * c, rot: (g.ang + rot) * 180 / Math.PI, size: F, ph: g.k / N * 6 + arm * 0.9, ch: ch });
        }
      }
      glyphs = finish(out);
    } else stencil.requestPaint();
  }

  function finish(out) {
    for (let i = 0; i < out.length; i++) { out[i].i = i; if (!out[i].ch) out[i].ch = text[i % text.length]; }
    return out;
  }

  function restOf(g) { const ti = g.i % len; return -((ti === 0 || ti === len - 1) ? 0.95 : 0.5) }
  function lightOf(g) {
    if (anim === "wave") { const w = 0.5 + 0.5 * Math.sin(g.ph - t * 1.2); return w > 0.93 ? 1 : -(0.45 + w * 0.5); }
    if (anim === "light") { const d = pos - g.i % len; if (d >= 0 && d < 10) return 1 - d / 10; }
    const ti = g.i % len; return -((ti === 0 || ti === len - 1) ? 0.95 : 0.5);
  }

  FontMetrics { id: wallMetrics; font.family: root.wallFont; font.pixelSize: 100 }

  function refresh() { pick(); build(); }
  Component.onCompleted: { mode = which === "rot" || (which === "dance" && !dance) ? "borj" : which; if (en) fetchVazha() }
  onModeChanged: { content.opacity = 0; refresh(); content.opacity = 1 }
  onWhichChanged: if (which !== "rot") go(which === "dance" && !dance ? "borj" : which)
  function go(m) { if (m !== mode) mode = m }
  function cycle(dir) {
    const all = ["borj", "vazha"].concat(dance ? ["dance"] : []);
    const m = all[(all.indexOf(mode) + dir + all.length) % all.length];
    if (which !== "rot" && Rice.cfg.wallMode !== "rot") Rice.cfg.wallMode = m;   // remembered, unless rotating
    go(m);
  }
  Connections { target: Rice; function onWallStep(dir) { root.cycle(dir) } }
  Connections { target: Rice; function onStanzaSeqChanged() { root.refresh() } }
  Connections { target: Rice.cfg; function onWallSrcChanged() { root.refresh() } }
  // slider drags fire many changes: rebuild once they settle
  Timer { id: rebuild; interval: 300; onTriggered: root.build() }
  onSizeChanged: rebuild.restart()
  onContrastChanged: rebuild.restart()
  onShapeChanged: rebuild.restart()
  onWallFontChanged: build()

  // one 30 Hz clock drives the reading light and the rotation (see SunBar: 300 Hz monitor)
  Timer {
    interval: 33; repeat: true
    running: root.anim !== "none" || (root.mode === "borj" && root.spin > 0)
    onTriggered: {
      root.t = Date.now() / 1000 % 100000;
      spinner.rotation = root.mode === "borj" ? (spinner.rotation + 0.033 * (root.spin / 100) * 0.08 * 180 / Math.PI) % 360 : 0;
    }
  }
  Timer {
    interval: root.rotateMinutes * 60000; running: root.which === "rot"; repeat: true
    onTriggered: root.cycle(1)
  }

  // hidden sampler for the stencil: read the head once, area-average cells via a summed-area table
  Canvas {
    id: stencil
    width: 800; height: 680
    property url head: "file://" + root.asset("portraits/vazha-head.png")
    property var sat: null
    Component.onCompleted: loadImage(head)
    onImageLoaded: if (root.mode === "vazha") requestPaint()
    onPaint: {
      if (root.mode !== "vazha" || !isImageLoaded(head)) return;
      const W = width, H = height;
      if (!sat) {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, W, H); ctx.drawImage(head, 0, 0, W, H);
        const d = ctx.getImageData(0, 0, W, H).data;
        ctx.clearRect(0, 0, W, H);
        sat = new Float64Array((W + 1) * (H + 1));
        for (let y = 0; y < H; y++) for (let x = 0, row = 0; x < W; x++) {
          const k = (y * W + x) * 4;
          row += d[k] * d[k + 3] / 65025;
          sat[(y + 1) * (W + 1) + x + 1] = sat[y * (W + 1) + x + 1] + row;
        }
      }
      const ph = Math.round(640 * root.shape / 100), pw = Math.round(W * ph / H), k = W / pw, T = root.contrast / 100;
      const avg = (x0, y0, x1, y1) => {
        x0 = Math.round(x0 * k); y0 = Math.round(y0 * k); x1 = Math.max(x0 + 1, Math.round(x1 * k)); y1 = Math.max(y0 + 1, Math.round(y1 * k));
        const S = sat, w = W + 1;
        return (S[y1 * w + x1] - S[y0 * w + x1] - S[y1 * w + x0] + S[y0 * w + x0]) / ((x1 - x0) * (y1 - y0));
      };
      // + pw * 0.065: the head (hair outline, nose) sits 52 px of 800 left of the picture's centre; centre the head
      const cells = (F) => {
        const adv = F * 0.66, gw = Math.floor(pw / adv), gh = Math.floor(ph / F), out = [];
        for (let r = 0; r < gh; r++) for (let c = 0; c < gw; c++) {
          const lum = avg(c * adv, r * F, (c + 1) * adv, (r + 1) * F);
          if (lum > 0.92 || lum < T) continue;
          out.push({ x: -pw / 2 + c * adv + adv / 2 + pw * 0.065, y: -ph / 2 + r * F + F / 2, rot: 0, size: F - 1, ph: (c * adv + r * F) / 90 });
        }
        return out;
      };
      let fit = 8;
      for (let F = 16; F >= 8; F--) if (cells(F).length >= root.text.length) { fit = F; break; }
      root.glyphs = root.finish(cells(Math.max(6, Math.min(80, Math.round(fit * root.size / 100)))));
    }
  }
  Rectangle { anchors.fill: parent; color: "#000000" }

  // ---- dance: letters flipping on the lines of a dancer, frame by frame (one shader) ---------
  FileView { id: danceInfo; path: Rice.danceDir ? Rice.danceDir + "/dance.json" : ""; blockLoading: true; printErrors: false }
  readonly property var dance: { try { return JSON.parse(danceInfo.text()) } catch (e) { return null } }
  readonly property real danceCh: dance ? height * 0.85 / dance.rows : 10     // the dancer fills 85% of the height
  readonly property real danceCw: danceCh * 0.73
  property real danceT: 0
  FrameAnimation { running: root.mode === "dance" && root.dance !== null; onTriggered: root.danceT += frameTime }
  Row {
    id: danceAtlas
    Repeater {
      model: root.mode === "dance" ? 33 : 0
      // each glyph clipped to its own slot, like the lock screen's letter rain
      Item {
        required property int index
        width: root.danceCw; height: root.danceCh; clip: true
        Text { anchors.centerIn: parent; text: "აბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰ"[parent.index]; color: "white"; font { family: root.wallFont; pixelSize: Math.round(root.danceCh * 0.95) } }
      }
    }
  }
  ShaderEffectSource { id: danceAtlasTex; sourceItem: danceAtlas; hideSource: true; textureSize: Qt.size(danceAtlas.width * 2, danceAtlas.height * 2) }
  Image { id: danceSheet; visible: false; smooth: false; source: root.dance ? "file://" + Rice.danceDir + "/dance.png" : "" }

  Item {
    id: content
    anchors.fill: parent
    Behavior on opacity { NumberAnimation { duration: 1200 } }

    // a dim red glow behind every mode (drawn first, under the letters)
    ShaderEffect {
      visible: Rice.cfg.glow
      anchors.fill: parent
      property size res: Qt.size(width, height)
      property real radius: 600 * root.s
      fragmentShader: "file://" + Quickshell.shellDir + "/shaders/glow.frag.qsb"
    }

    ShaderEffect {
      visible: root.mode === "dance" && root.dance !== null && danceSheet.status === Image.Ready
      anchors.fill: parent
      readonly property real f: root.dance ? Math.floor(root.danceT * root.dance.fps) % root.dance.frames : 0
      property variant atlas: danceAtlasTex
      property variant sheet: danceSheet
      property size res: Qt.size(width, height)
      property point origin: root.dance ? Qt.point((width - root.dance.cols * root.danceCw) / 2, (height - root.dance.rows * root.danceCh) / 2) : Qt.point(0, 0)
      property size cell: Qt.size(root.danceCw, root.danceCh)
      property size grid: root.dance ? Qt.size(root.dance.cols, root.dance.rows) : Qt.size(1, 1)
      property size tiles: root.dance ? Qt.size(root.dance.perRow, Math.ceil(root.dance.frames / root.dance.perRow)) : Qt.size(1, 1)
      property real frame: f
      property real t: root.danceT
      property real glyphs: 33
      // the loop's seam: a short dip, so the jump from the last pose to the first doesn't snap
      property real fade: root.dance ? Math.min(1, (f + 1) / 5, (root.dance.frames - f) / 5) : 1
      fragmentShader: "file://" + Quickshell.shellDir + "/shaders/dance.frag.qsb"
    }

    Item {
      // square around the centre; the base letters are baked into one texture (layer) and only that
      // texture rotates, so a 300 Hz monitor doesn't re-render thousands of glyphs every frame
      width: root.height; height: root.height
      x: (root.width - width) / 2; y: 0
      id: spinner
      rotation: 0
      Item {
        anchors.fill: parent
        layer.enabled: true; layer.smooth: true
        Item {
          x: parent.width / 2; y: parent.height / 2
      // base letters: static in light/none mode (no per-frame bindings); only "wave" animates them all
      Repeater {
        model: root.glyphs
        Text {
          required property var modelData
          readonly property real l: root.anim === "wave" ? root.lightOf(modelData) : root.restOf(modelData)
          readonly property bool red: root.ink === "r" || (root.ink === "wr" && modelData.i % 9 === 0)
          text: modelData.ch
          font.family: root.wallFont
          font.pixelSize: Math.max(1, modelData.size * root.s)
          x: modelData.x * root.s - width / 2
          y: modelData.y * root.s - height / 2
          rotation: modelData.rot
          color: l > 0 ? Qt.rgba(1, 1, 1, 0.55 + l * 0.45)
                       : red ? Qt.rgba(1, 42 / 255, 58 / 255, -l) : Qt.rgba(248 / 255, 244 / 255, 236 / 255, -l)
          style: l > 0.6 ? Text.Outline : Text.Normal
          styleColor: Qt.rgba(1, 1, 1, 0.25)
        }
      }
        }
      }
      Item {
        x: parent.width / 2; y: parent.height / 2
      // reading light: 10 lit letters per pass of the text, drawn over the base ones
      Repeater {
        model: root.anim === "light" ? 10 * Math.ceil(root.glyphs.length / root.len) : 0
        Text {
          required property int index
          readonly property int ti: Math.floor(root.pos) - index % 10
          readonly property int gi: Math.floor(index / 10) * root.len + ti
          readonly property var g: ti >= 0 && ti < root.len && gi < root.glyphs.length ? root.glyphs[gi] : null
          readonly property real l: g ? 1 - (root.pos - ti) / 10 : 0
          visible: g !== null
          text: g ? g.ch : ""
          font.family: root.wallFont
          font.pixelSize: g ? Math.max(1, g.size * root.s) : 1
          x: g ? g.x * root.s - width / 2 : 0
          y: g ? g.y * root.s - height / 2 : 0
          rotation: g ? g.rot : 0
          color: Qt.rgba(1, 1, 1, 0.55 + l * 0.45)
          style: l > 0.6 ? Text.Outline : Text.Normal
          styleColor: Qt.rgba(1, 1, 1, 0.25)
        }
      }
      }
    }
  }
}
