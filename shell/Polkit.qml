// The password prompt when an app asks for admin rights (installing from the launcher, NetworkManager…):
// Pharnavos is the session's polkit agent. Opens on the focused screen.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland

Scope {
  id: root
  PolkitAgent { id: agent }
  readonly property var flow: agent.flow

  PanelWindow {
    visible: agent.isActive && root.flow !== null
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "pharnavos-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: Qt.rgba(6 / 255, 5 / 255, 6 / 255, 0.55)
    onVisibleChanged: if (visible) { pw.text = ""; pw.forceActiveFocus() }

    Rectangle {
      anchors.centerIn: parent
      width: 460; height: box.implicitHeight + 48
      color: Theme.c("#0B090A"); radius: 6
      Stitch { anchors.fill: parent; inset: 6; stroke: 3; thread: Theme.red }
      Column {
        id: box
        x: 28; y: 24; width: parent.width - 56; spacing: 12
        Text { text: Rice.t("ადმინისტრატორის უფლება — ADMIN", "ADMIN"); color: Theme.red; font { family: Theme.sans; pixelSize: 11; weight: Font.Black; letterSpacing: 1.6 } }
        Text {
          width: parent.width; wrapMode: Text.Wrap; textFormat: Text.PlainText; color: Theme.cream; font { family: Theme.sans; pixelSize: 16; bold: true }
          // our own requests in words, not polkit's "run /nix/store/… as the super user"
          text: {
            const m = root.flow?.message ?? "", n = Apps.target;
            if (!Apps.busy || !m.includes("pharnavos-apps")) return m;
            return ({ install: Rice.t(n + "-ის დაყენება", "Install " + n), remove: Rice.t(n + "-ის წაშლა", "Remove " + n),
                      update: Rice.t("სისტემის განახლება", "Update the system"), undo: Rice.t("ბოლო ცვლილების გაუქმება", "Undo the last change") })[Apps.job] ?? m;
          }
        }
        Rectangle {
          width: parent.width; height: 44; radius: 4; color: "transparent"; border.color: pw.activeFocus ? Theme.red : Theme.c("#3A2E33")
          TextInput {
            id: pw
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            verticalAlignment: TextInput.AlignVCenter; clip: true
            echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
            color: Theme.cream; selectionColor: Theme.red; font { family: Theme.mono; pixelSize: 15 }
            enabled: root.flow?.isResponseRequired ?? false
            Keys.onPressed: ev => {
              if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { root.flow.submit(text); text = ""; ev.accepted = true }
              else if (ev.key === Qt.Key_Escape) { root.flow.cancelAuthenticationRequest(); ev.accepted = true }
            }
          }
          Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            visible: !pw.text; text: (root.flow?.inputPrompt || Rice.t("პაროლი", "Password")).replace(/:\s*$/, "")
            color: Theme.c("#5A5055"); font { family: Theme.sans; pixelSize: 14 }
          }
        }
        Text {
          visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; textFormat: Text.PlainText
          text: root.flow?.supplementaryMessage ?? ""
          color: root.flow?.supplementaryIsError ? Theme.red : Theme.c("#8C8186"); font { family: Theme.sans; pixelSize: 12; bold: true }
        }
        Text { text: Rice.t("↵ დადასტურება · Esc გაუქმება", "↵ confirm · Esc cancel"); color: Theme.c("#5A5055"); font { family: Theme.mono; pixelSize: 11 } }
      }
    }
  }
}
