// Close effect: when a window closes, it falls apart into Georgian letters (the wallpaper's
// letters) while Hyprland shrinks it away. GPU particles; the layer only exists while letters fall,
// so it never sits over fullscreen games and never takes input.
import QtQuick
import QtQuick.Particles
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
  id: wc
  required property var modelData
  screen: modelData
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.namespace: "pharnavos-close"
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; bottom: true; left: true; right: true }
  mask: Region {}
  color: "transparent"
  visible: false

  readonly property var mon: Hyprland.monitorFor(screen)
  property var geo: ({})    // window address → last known rect; a closed window is gone from Hyprland by then
  // note: geometry is snapshotted on Hyprland events only; a floating window drag-resized and
  // closed without any other event bursts at its old size. Poll here if that ever matters.
  // throttled, with a trailing run: windows opened in a quick burst are all in the last snapshot
  property bool again: false
  Timer {
    id: snap; interval: 120
    onTriggered: {
      if (wc.again) { wc.again = false; Hyprland.refreshToplevels(); restart() }
      const g = {};
      for (const t of Hyprland.toplevels.values) {
        const o = t.lastIpcObject;
        if (o && o.at) g[o.address.replace(/^0x/, "")] = { x: o.at[0], y: o.at[1], w: o.size[0], h: o.size[1], mon: o.monitor, ws: o.workspace?.id, full: !!o.fullscreen };
      }
      wc.geo = g;
    }
  }
  Component.onCompleted: { Hyprland.refreshToplevels(); snap.start() }
  Connections {
    target: Hyprland
    function onRawEvent(e) {
      if (e.name === "closewindow") wc.burst(wc.geo[e.data]);
      // throttle, not debounce: Firefox's stream of title events would postpone a restart() forever
      else { Hyprland.refreshToplevels(); if (snap.running) wc.again = true; else snap.start() }
    }
  }

  property var queue: []    // rects waiting for the particle scene to be built
  function burst(r) {
    if (!r) return console.info("pharnavos-close: no geometry cached");
    if (r.full || !wc.mon || r.mon !== wc.mon.id || r.ws !== wc.mon.activeWorkspace?.id)
      return console.info("pharnavos-close: skipped", JSON.stringify(r), "monitor", wc.mon?.id, "workspace", wc.mon?.activeWorkspace?.id);
    if (r.w < 160 || r.h < 120) return;      // menus, tooltips, small dialogs
    hide.restart();
    if (fx.item) fx.item.fire(r);
    else { wc.queue.push(r); wc.visible = true }
  }
  Timer { id: hide; interval: 1800; onTriggered: wc.visible = false }

  // a fresh particle scene every time the layer appears: a reused one draws nothing after a hide/show
  Loader {
    id: fx
    anchors.fill: parent
    active: wc.visible
    onLoaded: { for (const r of wc.queue) item.fire(r); wc.queue = [] }
    sourceComponent: Item {
      function fire(r) {
        for (const em of [cream, red]) { em.x = r.x - wc.screen.x; em.y = r.y - wc.screen.y; em.width = r.w; em.height = r.h }
        const n = Math.min(700, Math.round(r.w * r.h / 2200));
        cream.burst(Math.round(n * 0.65)); red.burst(Math.round(n * 0.35));
      }
      ParticleSystem { id: sys; anchors.fill: parent }
      Gravity { system: sys; angle: 90; magnitude: 1500 }
      component Letters: ImageParticle {
        system: sys
        // each particle starts in "pick" (1ms, still faded out) and jumps to one of the 33 letters at random,
        // where it stays (a letter outlasts any particle)
        sprites: [
          Sprite { name: "pick"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameWidth: 48; frameHeight: 48; frameDuration: 1; to: ({"l0": 1, "l1": 1, "l2": 1, "l3": 1, "l4": 1, "l5": 1, "l6": 1, "l7": 1, "l8": 1, "l9": 1, "l10": 1, "l11": 1, "l12": 1, "l13": 1, "l14": 1, "l15": 1, "l16": 1, "l17": 1, "l18": 1, "l19": 1, "l20": 1, "l21": 1, "l22": 1, "l23": 1, "l24": 1, "l25": 1, "l26": 1, "l27": 1, "l28": 1, "l29": 1, "l30": 1, "l31": 1, "l32": 1}) },
          Sprite { name: "l0"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 0; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l1"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 48; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l2"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 96; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l3"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 144; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l4"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 192; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l5"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 240; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l6"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 288; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l7"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 336; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l8"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 384; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l9"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 432; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l10"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 480; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l11"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 528; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l12"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 576; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l13"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 624; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l14"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 672; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l15"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 720; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l16"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 768; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l17"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 816; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l18"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 864; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l19"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 912; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l20"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 960; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l21"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 1008; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l22"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 1056; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l23"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 1104; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l24"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 1152; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l25"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 1200; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l26"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 1248; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l27"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 1296; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l28"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 1344; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l29"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 1392; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l30"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 1440; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l31"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 1488; frameWidth: 48; frameHeight: 48; frameDuration: 600000 },
          Sprite { name: "l32"; source: "file://" + Quickshell.shellDir + "/assets/cutouts/letters-atlas.png"; frameX: 1536; frameWidth: 48; frameHeight: 48; frameDuration: 600000 }
        ]
        rotationVariation: 25; rotationVelocityVariation: 80
        entryEffect: ImageParticle.Fade
      }
      Letters { groups: ["cream"]; color: "#EDE6DA" }
      Letters { groups: ["red"]; color: "#FF3B3B" }
      component Fall: Emitter {
        system: sys; enabled: false
        lifeSpan: 1000; lifeSpanVariation: 350
        size: 22; sizeVariation: 8
        velocity: AngleDirection { angle: 270; angleVariation: 50; magnitude: 160; magnitudeVariation: 160 }
      }
      Fall { id: cream; group: "cream" }
      Fall { id: red; group: "red" }
    }
  }
}
