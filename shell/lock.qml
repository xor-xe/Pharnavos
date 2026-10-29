// pharnavos lock screen — its own Quickshell instance, so a crash of the bar/shell can't take the lock down.
//   preview (nothing locks; password 1234; Esc closes):  PHARNAVOS_LOCK_PREVIEW=1 pharnavos-lock
//   test    (real lock + real password; unlocks itself after 30 s): PHARNAVOS_LOCK_TEST=1 pharnavos-lock
//   real:   pharnavos-lock   (falls back to hyprlock if this lock ever dies)
// Look: PHARNAVOS_LOCK=giorgi|flag|borj, else the one picked in the control centre (ჩაკეტვა tab), else random.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

ShellRoot {
  id: root
  readonly property bool preview: Quickshell.env("PHARNAVOS_LOCK_PREVIEW") === "1"
  readonly property bool test: Quickshell.env("PHARNAVOS_LOCK_TEST") === "1"
  // look: PHARNAVOS_LOCK env, else the control centre's choice (pharnavos settings), else random
  FileView { id: settings; path: Quickshell.env("HOME") + "/.local/state/pharnavos/settings.json"; blockLoading: true }
  readonly property var cfg: { try { return JSON.parse(settings.text()) } catch (e) { return {} } }
  readonly property string chosen: cfg.lockLook ?? "random"
  readonly property string clockFmt: cfg.clockFmt ?? "24"
  // picked once: a binding would re-pick "random" whenever the settings reload, so the lock could
  // open as one look and jump to another
  property string variant: ""
  Component.onCompleted: {
    const v = Quickshell.env("PHARNAVOS_LOCK") || chosen;
    variant = ["giorgi", "flag", "borj"].includes(v) ? v : ["giorgi", "flag", "borj"][Math.floor(Math.random() * 3)];
  }

  property string mood: "idle"
  property string message: ""
  property bool busy: false
  property int clearSeq: 0

  function wrong() { mood = "bad"; message = Rice.t("არასწორი პაროლი", "Wrong password"); busy = false; clearSeq++ }
  function edited() { mood = "idle"; message = "" }
  function accept() { mood = "ok"; message = ""; busy = false; done.start() }
  Timer { id: done; interval: 1100; onTriggered: { lock.locked = false; Qt.quit() } }

  // ---- real authentication ----------------------------------------------------------------
  property string pending: ""
  PamContext {
    id: pam
    onPamMessage: if (responseRequired) { respond(root.pending); root.pending = "" }
    onCompleted: result => { if (result === PamResult.Success) root.accept(); else root.wrong() }
  }
  function submit(pw) {
    if (busy) return;
    if (preview) { if (pw === "1234") accept(); else wrong(); return }
    busy = true; pending = pw; pam.start();
  }

  // safety net while testing: never stay locked longer than 30 s
  Timer { running: root.test; interval: 30000; onTriggered: { lock.locked = false; Qt.quit() } }

  // ---- real lock --------------------------------------------------------------------------
  WlSessionLock {
    id: lock
    locked: !root.preview
    WlSessionLockSurface {
      color: "black"
      LockSurface {
        anchors.fill: parent
        variant: root.variant; mood: root.mood; message: root.message; busy: root.busy; clockFmt: root.clockFmt; clearSeq: root.clearSeq
        onSubmitted: pw => root.submit(pw)
        onEdited: root.edited()
      }
    }
  }

  // ---- preview: an ordinary full-screen window ---------------------------------------------
  Variants {
    model: root.preview ? Quickshell.screens : []
    PanelWindow {
      required property var modelData
      screen: modelData
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.namespace: "pharnavos-lock-preview"
      exclusionMode: ExclusionMode.Ignore
      anchors { top: true; bottom: true; left: true; right: true }
      color: "black"
      LockSurface {
        anchors.fill: parent
        variant: root.variant; mood: root.mood; message: root.message; busy: root.busy; clockFmt: root.clockFmt; clearSeq: root.clearSeq
        onSubmitted: pw => root.submit(pw)
        onEdited: root.edited()
        onEscaped: Qt.quit()
      }
    }
  }
}
