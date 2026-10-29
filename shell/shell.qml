//@ pragma UseQApplication
// Pharnavos — a Georgian desktop shell for Hyprland, built on Quickshell. Started by `pharnavos`.
import QtQuick
import Quickshell

ShellRoot {
  Variants {
    model: Quickshell.screens
    Wallpaper {}
  }
  Variants {
    model: Quickshell.screens
    SunBar {}
  }
  Variants {
    model: Quickshell.screens
    WinClose {}
  }
}
