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

  // what's on the system already, by package name; an app your configuration installs counts too.
  // ponytail: matched by name, so a package renamed in your config (vlc vs vlc-bin) isn't recognised
  property var system: []
  function onSystem(name) { return system.includes(name.split(".").pop()) }
  Process {
    id: sysP
    command: [root.bin, "system"]
    stdout: StdioCollector { onStreamFinished: { root.system = text.split("\n").filter(l => l); root.finish() } }
  }
  function refresh() { if (on && !sysP.running) sysP.running = true }

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
    if (!system.length) refresh();
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
      // 126/127: the password prompt was dismissed
      root.done = code === 126 || code === 127 ? null : { job: root.job, name: root.target, ok: code === 0, last: root.last, changes: root.changes };
      root.job = "";
      sysP.running = true;    // then finish(): a removed app may still be there from your configuration
    }
  }
  property var done: null
  function finish() {
    const d = done;
    if (!d) return;
    done = null;
    const n = d.name, kept = d.ok && d.job === "remove" && onSystem(n);
    const title = !d.ok ? Rice.t("ვერ მოხერხდა", "That didn't work")
      : kept ? Rice.t(n + " გამშვებიდან მოიხსნა", n + " is off the launcher's list")
      : ({ install: Rice.t(n + " დაყენდა", n + " is installed"), remove: Rice.t(n + " წაიშალა", n + " was removed"),
           update: Rice.t("სისტემა განახლდა", "System updated"), undo: Rice.t("ბოლო ცვლილება გაუქმდა", "Last change undone") })[d.job];
    const body = !d.ok ? d.last
      : kept ? Rice.t("შენი კონფიგურაცია მაინც აყენებს, ამიტომ დარჩა.", "It's still installed by your configuration.")
      : d.changes.filter(c => c.includes("→")).slice(0, 6)
          // the running shell isn't restarted by a rebuild (nix/hm.nix): say when it changed
          .concat(d.changes.some(c => /^pharnavos[:-]/.test(c)) ? [Rice.t("ფარნავოსი განახლდა: ახალი ვერსია შემდეგ შესვლაზე ჩაირთვება.", "Pharnavos was updated: the new version starts next time you log in.")] : [])
          .join("\n");
    notify.exec(["notify-send", "-a", "Pharnavos", "-i", d.ok ? "system-software-install" : "dialog-error", title, body]);
  }
  Process { id: notify }
}
