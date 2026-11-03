// System readings for the bar: CPU / RAM from /proc, network (state, Wi-Fi signal, traffic), power profile.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  property int cpu: 0
  property int ram: 0
  property real ramUsedG: 0
  property real ramTotalG: 0
  property bool online: false
  property string profile: "balanced"
  property string ssid: ""          // Wi-Fi network in use ("" = none: wired or offline)
  property int signal: 0            // its strength, 0..100
  property real rxRate: 0           // bytes/s on the default route's interface
  property real txRate: 0
  property string iface: ""
  // the last minute of traffic (30 readings, 2 s apart) for the Wi-Fi popup's graph: just numbers
  property var rxHist: Array(60).fill(0)
  property var txHist: Array(60).fill(0)

  property var prev: [0, 0]
  FileView {
    id: stat; path: "/proc/stat"
    onLoaded: {
      const v = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
      const total = v.reduce((a, b) => a + b, 0), idle = v[3] + v[4];
      if (root.prev[0] > 0 && total > root.prev[0]) root.cpu = Math.round(100 * (1 - (idle - root.prev[1]) / (total - root.prev[0])));
      root.prev = [total, idle];
    }
  }
  FileView {
    id: mem; path: "/proc/meminfo"
    onLoaded: {
      const kb = k => Number(text().match(new RegExp("^" + k + ":\\s+(\\d+)", "m"))[1]);
      const total = kb("MemTotal"), used = total - kb("MemAvailable");
      root.ram = Math.round(100 * used / total);
      root.ramUsedG = Math.round(used / 104857.6) / 10; root.ramTotalG = Math.round(total / 104857.6) / 10;
    }
  }
  Process { id: net; command: ["nmcli", "-t", "-f", "STATE", "general"]; stdout: StdioCollector { onStreamFinished: root.online = text.trim().startsWith("connected") } }
  // no power-profiles-daemon (or it's switched off): the bar hides its gauge
  property bool powerAvailable: true
  Process {
    id: pp; command: ["powerprofilesctl", "get"]
    stdout: StdioCollector { onStreamFinished: root.profile = text.trim() || root.profile }
    onExited: code => root.powerAvailable = code === 0
  }
  Process { id: ppSet }
  Process {
    id: wifi
    command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SSID", "dev", "wifi", "list", "--rescan", "no"]
    stdout: StdioCollector {
      onStreamFinished: {
        const l = text.split("\n").find(l => l.startsWith("*:"));
        const p = l ? l.split(":") : [];
        root.ssid = l ? p.slice(2).join(":").replace(/\\:/g, ":") : ""; root.signal = l ? Number(p[1]) : 0;
      }
    }
  }

  // traffic: the default route's interface in /proc/net/route, its byte counters in /proc/net/dev
  FileView {
    id: route; path: "/proc/net/route"
    onLoaded: { const l = text().split("\n").find(l => l.split(/\s+/)[1] === "00000000"); root.iface = l ? l.split(/\s+/)[0] : "" }
  }
  property var prevNet: [0, 0, 0]
  FileView {
    id: netdev; path: "/proc/net/dev"
    onLoaded: {
      const l = text().split("\n").find(l => l.trim().startsWith(root.iface + ":"));
      if (!root.iface || !l) { root.rxRate = root.txRate = 0; return }
      const v = l.split(":")[1].trim().split(/\s+/).map(Number), now = Date.now();
      if (root.prevNet[2] > 0) {
        const dt = (now - root.prevNet[2]) / 1000;
        root.rxRate = Math.max(0, (v[0] - root.prevNet[0]) / dt); root.txRate = Math.max(0, (v[8] - root.prevNet[1]) / dt);
      }
      root.prevNet = [v[0], v[8], now];
      root.rxHist = root.rxHist.slice(1).concat([root.rxRate]); root.txHist = root.txHist.slice(1).concat([root.txRate]);
    }
  }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: netdev.reload() }
  // screen backlight (laptops): "" when there's none. Written through brightnessctl (logind, no root needed);
  // the bar, the slider and the brightness keys (`pharnavos ipc call brightness up|down`) all go through setBright
  property string backlight: ""
  property real bright: 0
  Process { running: true; command: ["sh", "-c", "ls -d /sys/class/backlight/* 2>/dev/null | head -1"]; stdout: StdioCollector { onStreamFinished: root.backlight = text.trim() } }
  FileView { id: blMax; path: root.backlight ? root.backlight + "/max_brightness" : "" }
  FileView { id: blCur; path: root.backlight ? root.backlight + "/brightness" : ""; onLoaded: if (!blSet.running) root.bright = Number(text()) / Math.max(1, Number(blMax.text())) }
  Process { id: blSet }
  function setBright(f) {
    if (!backlight) return;
    bright = Math.max(0.01, Math.min(1, f));
    blSet.exec(["brightnessctl", "-q", "set", Math.round(bright * 100) + "%"]);
    Rice.brightness(Math.round(bright * 100));
  }
  IpcHandler {
    target: "brightness"
    function up(): void { root.setBright(root.bright + 0.05) }
    function down(): void { root.setBright(root.bright - 0.05) }
  }
  function rate(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b >= 1024 ? Math.round(b / 1024) + " KB/s" : Math.round(b) + " B/s" }

  function setProfile(p) { profile = p; ppSet.exec(["powerprofilesctl", "set", p]) }
  function cycleProfile() {
    profile = { "power-saver": "balanced", "balanced": "performance", "performance": "power-saver" }[profile] ?? "balanced";
    ppSet.exec(["powerprofilesctl", "set", profile]);
  }

  Timer {
    interval: 2000; running: true; repeat: true; triggeredOnStart: true
    property int n: 0
    onTriggered: {
      stat.reload(); mem.reload(); route.reload(); if (root.backlight) blCur.reload();
      if (n++ % 5 === 0) { net.running = true; pp.running = Rice.power; wifi.running = true; }
    }
  }
}
