// Shared state: persisted settings (wallpaper, todos, awake) + runtime UI flags.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
  id: root
  readonly property JsonAdapter cfg: adapter

  // Hyprland 0.56+ is configured in Lua, and `dispatch` there takes Lua (hl.dsp.*) instead of the old
  // "workspace 3" strings; every dispatch goes through dispatch(old, lua)
  property bool hyprLua: false
  Process {
    running: true
    command: ["hyprctl", "version", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const m = (JSON.parse(text).tag || "").match(/(\d+)\.(\d+)/);
          root.hyprLua = !!m && (+m[1] > 0 || +m[2] >= 56);
        } catch (e) {}
      }
    }
  }
  function dispatch(old, lua) { Hyprland.dispatch(hyprLua ? lua : old) }
  function luaStr(s) { return JSON.stringify(String(s)) }   // a JSON string is a valid Lua string
  property bool ccOpen: false
  property bool launcherOpen: false
  property string launcherText: ""    // prefill, e.g. "=" to open straight into the calculator
  property int stanzaSeq: 0          // bump to make the wallpaper pick a new stanza
  property string wallText: ""       // what the wallpaper is currently showing
  property string wallInfo: ""       // what it is: "r:<stanza>", "v:<poem title>"
  property bool notifShowAll: false   // bell: show every notification still in history
  property var seen: ({})              // ids whose popup already ran its countdown
  property int notifCount: 0
  // set by the home-manager module (PHARNAVOS_* env); the in-app settings file wins where it has a value
  readonly property string lang: cfg.lang || Quickshell.env("PHARNAVOS_LANG") || "ka"
  // programs.pharnavos.wallpaper.dance: a directory with dance.png + dance.json (a dancer's line art)
  readonly property string danceDir: Quickshell.env("PHARNAVOS_DANCE") || ""
  // every UI string is written t("ქართული", "English"); the art (poems, letter rain) stays Georgian
  function t(ka, en) { return lang === "en" ? en : ka }
  readonly property string name: cfg.name || Quickshell.env("PHARNAVOS_NAME") || Quickshell.env("USER")
  readonly property string fontHeading: cfg.fontHeading || Quickshell.env("PHARNAVOS_FONT_HEADING") || ""
  readonly property string fontLabel: cfg.fontLabel || Quickshell.env("PHARNAVOS_FONT_LABEL") || ""
  readonly property string terminal: Quickshell.env("PHARNAVOS_TERMINAL") || "foot"
  readonly property bool power: Quickshell.env("PHARNAVOS_POWER") !== "0"   // power-profile gauge on the bar
  // launcher AI (programs.pharnavos.ai): off unless the module sets an API
  readonly property string aiApi: Quickshell.env("PHARNAVOS_AI_API") || ""          // "" | ollama | openai
  readonly property bool ai: aiApi !== ""
  readonly property string aiUrl: (Quickshell.env("PHARNAVOS_AI_URL") || "http://localhost:11434").replace(/\/$/, "")
  readonly property string aiKeyFile: Quickshell.env("PHARNAVOS_AI_KEY_FILE") || ""
  readonly property bool aiLocal: /^https?:\/\/(localhost|127\.|\[::1\])/.test(aiUrl)
  readonly property string askModel: Quickshell.env("PHARNAVOS_AI_MODEL") || ""
  readonly property string translateModel: Quickshell.env("PHARNAVOS_AI_TRANSLATE_MODEL") || askModel

  FileView {
    id: settingsFile
    // fixed path (not per-shell): the separate lock instance reads it too. Loaded before the first
    // frame, so language and fonts are right from the start (no flash of Georgian / default fonts)
    blockLoading: true
    path: Quickshell.env("HOME") + "/.local/state/pharnavos/settings.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    // first run: create the file, then re-arm the watch (a watch on a missing file never fires)
    onLoadFailed: e => { if (e === FileViewError.FileNotFound) { writeAdapter(); rewatch.start() } }
    JsonAdapter {
      id: adapter
      property string wallMode: "rot"   // borj | vazha | dance | rot
      property string wallSrc: "auto"   // auto | r | v
      property string anim: "light"     // light | wave | none
      property int speed: 40
      property int spin: 35
      property int size: 100
      property int shape: 100           // size of the Borjgali / head itself
      property int contrast: 52
      property string ink: "r"          // w | wr | r
      property bool glow: true          // the dim red glow behind the wallpaper
      property bool awake: false
      property string lockLook: "random"  // random | giorgi | flag | borj
      property string clockFmt: "24"       // 24 | ka (12h + დილის/შუადღის/საღამოს/ღამის) | ampm
      property string lang: ""             // ka | en; "" = programs.pharnavos.language (default ka)
      property string name: ""             // greeting name; "" = your login name
      property string fontHeading: ""      // path to your own .ttf/.otf for headings; "" = FiraGO
      property string fontLabel: ""        // same for labels; "" = BPG Excelsior Caps
      property var todos: []
      property var launches: ({})       // launch counts per desktop entry id (ranks the launcher)
    }
  }
  Timer { id: rewatch; interval: 500; onTriggered: { settingsFile.watchChanges = false; settingsFile.watchChanges = true } }

  IpcHandler {
    target: "cc"
    function toggle(): void { root.ccOpen = !root.ccOpen }
  }
  IpcHandler {
    target: "launcher"
    function toggle(): void { root.launcherOpen = !root.launcherOpen }
    function open(text: string): void { root.launcherOpen = false; root.launcherText = text; root.launcherOpen = true }
  }
  // Super+W / Super+Shift+W: next / previous wallpaper (every screen's Wallpaper listens)
  signal wallStep(int dir)
  IpcHandler {
    target: "wall"
    function next(): void { root.wallStep(1) }
    function prev(): void { root.wallStep(-1) }
  }
  IpcHandler {
    target: "notif"
    function history(): void { root.notifShowAll = !root.notifShowAll }
  }
}
