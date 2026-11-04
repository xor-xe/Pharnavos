{ lib, stdenvNoCC, makeWrapper, writeShellApplication, git, coreutils, quickshell, cava, networkmanager, networkmanagerapplet, blueman, power-profiles-daemon, curl, poppler-utils, procps, hyprlock, brightnessctl, libnotify, jq, brotli, util-linux }:

let
  # what the shell calls at runtime; hyprctl / systemctl / loginctl come from the system.
  # nm-connection-editor (networkmanagerapplet) and blueman-manager open from the bar's icons.
  path = lib.makeBinPath [ quickshell cava networkmanager networkmanagerapplet blueman power-profiles-daemon curl poppler-utils procps hyprlock brightnessctl libnotify ];
  # installs apps from the launcher; runs as root through pkexec, so it brings its own PATH
  apps = writeShellApplication { name = "pharnavos-apps"; runtimeInputs = [ curl jq brotli util-linux git coreutils ]; text = builtins.readFile ./apps.sh; };
in
stdenvNoCC.mkDerivation {
  pname = "pharnavos";
  version = "0.1.0";
  src = ../shell;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    share=$out/share/pharnavos
    mkdir -p $share $out/bin
    cp -r . $share

    # `pharnavos` runs the shell; `pharnavos ipc call launcher toggle` etc. talk to it
    mkdir -p $out/libexec
    makeWrapper ${quickshell}/bin/qs $out/libexec/pharnavos \
      --add-flags "-p $share/shell.qml" --prefix PATH : ${path} --set PHARNAVOS_APPS ${lib.getExe apps}
    # ipc goes to the running shell by its pid: after an update (which doesn't restart it) the running
    # shell is the previous version, which the new one can't find by its path
    cat > $out/bin/pharnavos <<EOF
    #!/bin/sh
    if [ "\$1" = ipc ] && pid=\$(systemctl --user show -p MainPID --value pharnavos 2>/dev/null) && [ "\''${pid:-0}" != 0 ]; then
      shift; exec $out/libexec/pharnavos ipc --pid "\$pid" "\$@"
    fi
    exec $out/libexec/pharnavos "\$@"
    EOF
    chmod +x $out/bin/pharnavos
    ln -s ${lib.getExe apps} $out/bin/pharnavos-apps

    # the lock screen runs as its own instance, so a crash of the shell can't unlock you; if the
    # lock itself dies while locked, Hyprland keeps the session locked and hyprlock takes over
    cat > $out/bin/pharnavos-lock <<EOF
    #!/bin/sh
    export PATH=${path}:\$PATH
    # a preview locks nothing, so it never falls back to hyprlock
    [ "\$PHARNAVOS_LOCK_PREVIEW" = 1 ] && exec qs -p $share/lock.qml
    pgrep -x hyprlock >/dev/null && exit 0
    pgrep -f '$share/lock.qml' >/dev/null && exit 0
    qs -p $share/lock.qml && exit 0
    exec hyprlock
    EOF
    chmod +x $out/bin/pharnavos-lock
    runHook postInstall
  '';

  meta = {
    description = "A Georgian desktop shell for Hyprland, built on Quickshell";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "pharnavos";
  };
}
