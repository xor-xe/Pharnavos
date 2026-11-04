// Apps from the launcher: search NixOS's packages, install / remove / update through pharnavos-apps
// (nix/apps.sh) as root via pkexec. Only with programs.pharnavos.apps set (the one-command installer sets it).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  readonly property string bin: Quickshell.env("PHARNAVOS_APPS") || ""
  readonly property bool on: bin !== "" && managed
  property bool managed: false

  // programs.pharnavos.apps: where the system's flake is ("" = off)
  property string flake: ""
  FileView {
    path: "/etc/pharnavos/apps"; printErrors: false
    onLoaded: root.flake = (text().match(/^flake=(.*)$/m) ?? ["", ""])[1]
  }
  // what the launcher installed: [{ name, unfree }]
  property var installed: []
  FileView {
    path: root.flake ? root.flake + "/apps.json" : ""; watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: { root.managed = true; try { root.installed = JSON.parse(text()) } catch (e) {} }
    onLoadFailed: root.managed = false
  }

  // ---- search ------------------------------------------------------------------------------
  property bool indexing: false
  property string query: ""
  property var results: []      // [{ name, version, unfree, desc }], best first
  Process {
    id: indexP
    command: [root.bin, "index"]
    onExited: { root.indexing = false; if (root.query) searchP.exec([root.bin, "search", root.query]) }
  }
  // the index (a few MB) is built once a week, the first time the launcher looks for an app
  function find(q) {
    query = q.trim().toLowerCase();
    if (!query) { results = []; return }
    if (!indexing && !indexP.running) { indexing = true; indexP.running = true; return }
    if (!indexP.running) debounce.restart();
  }
  Timer { id: debounce; interval: 120; onTriggered: searchP.exec([root.bin, "search", root.query]) }
  Process {
    id: searchP
    stdout: StdioCollector {
      onStreamFinished: {
        const q = root.query;
        root.results = text.split("\n").filter(l => l).map(l => {
          const [name, version, unfree, desc] = l.split("\t");
          const leaf = name.split(".").pop().toLowerCase();
          // the whole name, a word of it (google-chrome), its start, inside it, only the description;
          // then top-level before python3Packages.x, shorter before longer
          const hit = leaf === q ? 4 : leaf.split(/[-_]/).includes(q) ? 3 : leaf.startsWith(q) ? 2 : leaf.includes(q) ? 1 : 0;
          return { name, version, unfree: unfree === "unfree", desc: desc ?? "", score: hit * 10 - name.split(".").length - leaf.length / 100 };
        }).sort((a, b) => b.score - a.score).slice(0, 8);
      }
    }
  }

  // ---- jobs: one at a time ------------------------------------------------------------------
  property string job: ""        // "install", "remove", "update", "undo"
  property string target: ""     // the app's name
  property string last: ""       // the newest output line, for the bar
  property var changes: []       // update: what changed
  readonly property bool busy: job !== ""
  function run(verb, name, unfree) {
    if (busy) return;
    job = verb; target = name ?? ""; last = ""; changes = [];
    jobP.exec(["pkexec", bin, verb].concat(name ? [name] : [], unfree ? ["--unfree"] : []));
  }
  Process {
    id: jobP
    stdout: SplitParser { onRead: l => { if (l.startsWith("CHANGE ")) root.changes = root.changes.concat([l.slice(7)]); else if (l.trim()) root.last = l } }
    stderr: SplitParser { onRead: l => { if (l.trim()) root.last = l } }
    onExited: code => {
      const n = root.target, ok = code === 0;
      // 126/127: the password prompt was dismissed
      if (code !== 126 && code !== 127) {
        const title = ok ? ({ install: Rice.t(n + " დაყენდა", n + " is installed"), remove: Rice.t(n + " წაიშალა", n + " was removed"),
                              update: Rice.t("სისტემა განახლდა", "System updated"), undo: Rice.t("ბოლო ცვლილება გაუქმდა", "Last change undone") })[root.job]
                         : Rice.t("ვერ მოხერხდა", "That didn't work");
        const body = ok ? root.changes.filter(c => c.includes("→")).slice(0, 6).join("\n") : root.last;
        notify.exec(["notify-send", "-a", "Pharnavos", "-i", ok ? "system-software-install" : "dialog-error", title, body]);
      }
      if (ok && root.job === "update") root.outdated = false;
      root.job = "";
    }
  }
  Process { id: notify }

  // ---- a newer NixOS? once a day, one small download -----------------------------------------
  property bool outdated: false
  Process { id: outP; command: [root.bin, "outdated"]; stdout: StdioCollector { onStreamFinished: root.outdated = text.trim() === "yes" } }
  Timer { interval: 24 * 3600 * 1000; repeat: true; triggeredOnStart: true; running: root.on; onTriggered: outP.running = true }
}
